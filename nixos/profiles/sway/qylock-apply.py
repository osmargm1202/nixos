#!/usr/bin/env python3
"""Root-only, allowlisted SDDM theme switch. Does not start/stop any service.

Paths and Qt environment are substituted at build time in the immutable Nix
store. The CLI accepts only `select SLUG` or `init`; never a user-provided path.
"""
import configparser
import fcntl
import json
import os
from pathlib import Path
import stat
import sys
import tempfile

PACKAGE = Path('@package@')
DEFAULT_THEME = '@default_theme@'
QT_ENVIRONMENT = json.loads('@qt_environment@')
STATE = Path('/var/lib/orgm-qylock')
DROPIN = Path('/etc/sddm.conf.d/90-orgm-qylock.conf')
MARKER = '# Managed by orgm-qylock; changes take effect at the next login.\n'


def trusted_directory(path):
    path.mkdir(mode=0o755, parents=True, exist_ok=True)
    info = path.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.geteuid() or info.st_mode & 0o022:
        raise ValueError(f'Unsafe root state directory: {path}')


def atomic_text(path, text, mode=0o644):
    fd, name = tempfile.mkstemp(prefix='.'+path.name+'-', dir=path.parent)
    try:
        os.fchmod(fd, mode)
        with os.fdopen(fd, 'w') as stream:
            stream.write(text)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(name, path)
    finally:
        if os.path.lexists(name):
            os.unlink(name)


def greeter_environment(dropin):
    # Retain non-Qt settings such as the Wayland shell integration. Ignore our
    # previous generated file so old store closures do not accumulate forever.
    settings = configparser.ConfigParser(interpolation=None, strict=False)
    settings.optionxform = str
    paths = sorted(Path('/usr/lib/sddm/sddm.conf.d').glob('*.conf'))
    paths += sorted(Path('/etc/sddm.conf.d').glob('*.conf'))
    paths += [Path('/etc/sddm.conf')]
    settings.read([str(p) for p in paths if p != dropin and p.is_file()])
    values = {}
    for assignment in settings.get('General', 'GreeterEnvironment', fallback='').split(','):
        key, separator, value = assignment.partition('=')
        if separator:
            values[key.strip()] = value
    values.update(QT_ENVIRONMENT)
    return ','.join(f'{key}={value}' for key, value in sorted(values.items()))


def managed_dropin(path, state):
    if not os.path.lexists(path):
        return False
    info = path.lstat()
    if info.st_uid != os.geteuid() or not (stat.S_ISREG(info.st_mode) or stat.S_ISLNK(info.st_mode)):
        raise ValueError('Refusing to replace an unmanaged SDDM drop-in')
    if stat.S_ISREG(info.st_mode) and not info.st_mode & 0o022:
        if not path.read_text().startswith(MARKER):
            raise ValueError('Refusing to replace an unmanaged SDDM drop-in')
        return False
    if stat.S_ISLNK(info.st_mode):
        # NixOS owns this entry after a rebuild. Never replace its store link;
        # Nix removes the declarative drop-in when leaving the Sway profile.
        resolved = path.resolve(strict=True)
        target = resolved.stat()
        if (not resolved.is_relative_to('/nix/store') or target.st_uid != 0 or target.st_mode & 0o022
                or not path.read_text().startswith(MARKER)):
            raise ValueError('Untrusted declarative SDDM drop-in')
        parser = configparser.ConfigParser(interpolation=None)
        parser.optionxform = str
        parser.read(path)
        if parser.get('Theme', 'Current') != 'current' or parser.get('Theme', 'ThemeDir') != str(state/'sddm'):
            raise ValueError('Declarative SDDM drop-in does not point at the managed state')
        environment = dict(entry.split('=', 1) for entry in parser.get('General', 'GreeterEnvironment').split(',') if '=' in entry)
        if any(environment.get(key) != value for key, value in QT_ENVIRONMENT.items()):
            raise ValueError('SDDM Qt runtime changed; rebuild NixOS before choosing a theme')
        return True
    raise ValueError('Unsafe SDDM drop-in')


def snapshot(path):
    if not os.path.lexists(path):
        return None
    descriptor, temporary = tempfile.mkstemp(prefix='.qylock-backup-', dir=path.parent)
    os.close(descriptor)
    os.unlink(temporary)
    backup = Path(temporary)
    if path.is_symlink():
        backup.symlink_to(os.readlink(path))
    else:
        os.link(path, backup)
    return backup


def apply_theme(slug, package=PACKAGE, state=STATE, dropin=DROPIN):
    catalog = json.loads((package/'share/orgm-qylock/catalog.json').read_text())
    if slug not in {item['id'] for item in catalog}:
        raise ValueError('Theme is not in the pinned qylock catalog')
    theme_root = (package/'share/orgm-qylock/themes').resolve(strict=True)
    theme = (theme_root/slug).resolve(strict=True)
    if not theme.is_relative_to(theme_root) or not (theme/'Main.qml').is_file():
        raise ValueError('Theme escaped the pinned source or has no Main.qml')
    trusted_directory(state)
    trusted_directory(state/'sddm')
    trusted_directory(dropin.parent)
    lock_fd = os.open(state/'apply.lock', os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW | os.O_CLOEXEC, 0o600)
    backups = []
    temporary = state/'sddm'/f'.current-{os.getpid()}'
    try:
        lock_info = os.fstat(lock_fd)
        if not stat.S_ISREG(lock_info.st_mode) or lock_info.st_uid != os.geteuid() or lock_info.st_mode & 0o077:
            raise ValueError('Unsafe theme switch lock')
        fcntl.flock(lock_fd, fcntl.LOCK_EX)
        declarative = managed_dropin(dropin, state)
        target, selection = state/'sddm/current', state/'selection'
        if os.path.lexists(target) and (not target.is_symlink() or target.lstat().st_uid != os.geteuid()):
            raise ValueError('Refusing to replace a non-owned theme symlink')
        if os.path.lexists(selection):
            info = selection.lstat()
            if not stat.S_ISREG(info.st_mode) or info.st_uid != os.geteuid() or info.st_mode & 0o022:
                raise ValueError('Unsafe theme selection state')
        if os.path.lexists(temporary):
            raise ValueError('Unexpected temporary theme entry')
        for path in ([dropin] if not declarative else []) + [selection, target]:
            backups.append((path, snapshot(path)))
        temporary.symlink_to(theme)
        try:
            if not declarative:
                content = MARKER + '[Theme]\nCurrent=current\nThemeDir=' + str(state/'sddm')
                content += '\n[General]\nGreeterEnvironment=' + greeter_environment(dropin) + '\n'
                atomic_text(dropin, content)
            atomic_text(selection, slug+'\n')
            # The shared atomic symlink is the commit point for BOTH the next
            # greeter and the locker; neither trusts a premature user preference.
            os.replace(temporary, target)
        except BaseException:
            for path, backup in reversed(backups):
                if backup is None:
                    path.unlink(missing_ok=True)
                else:
                    os.replace(backup, path)
            raise
    finally:
        temporary.unlink(missing_ok=True)
        for path, backup in backups:
            if backup is not None:
                backup.unlink(missing_ok=True)
        os.close(lock_fd)


def main(args):
    if os.geteuid() != 0:
        raise PermissionError('Use pkexec; this helper only changes root-owned SDDM state')
    if args == ['init']:
        selection = STATE/'selection'
        slug = selection.read_text().strip() if selection.is_file() else DEFAULT_THEME
        choices = {item['id'] for item in json.loads((PACKAGE/'share/orgm-qylock/catalog.json').read_text())}
        if slug not in choices:
            slug = DEFAULT_THEME
    elif len(args) == 2 and args[0] == 'select':
        slug = args[1]
    else:
        raise ValueError('Usage: orgm-qylock-apply init | select THEME_ID')
    apply_theme(slug)


if __name__ == '__main__':
    try:
        main(sys.argv[1:])
    except (OSError, ValueError, KeyError) as error:
        print('orgm-qylock-apply:', error, file=sys.stderr)
        sys.exit(1)
