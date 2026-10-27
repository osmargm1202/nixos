#!/usr/bin/env python3
"""Portable installer: stage exact resources and mock all service/privilege calls."""
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[1]
BASH = shutil.which('bash')


def snapshot(home):
    return sorted((str(p.relative_to(home)), os.readlink(p) if p.is_symlink() else p.read_bytes())
                  for p in home.rglob('*') if p.is_file() or p.is_symlink())


with tempfile.TemporaryDirectory(prefix='server-persistence-') as directory:
    root = Path(directory)
    mock = root / 'mock'
    mock.mkdir()
    log = root / 'calls.jsonl'
    archives = root / 'archives'
    archives.mkdir()
    for name in ('tmux-resurrect', 'tmux-continuum'):
        with tarfile.open(archives / f'{name}.tar.gz', 'w:gz') as archive:
            info = tarfile.TarInfo(f'{name}/plugin.tmux')
            data = b'#!/usr/bin/env bash\nexit 0\n'
            info.size = len(data)
            info.mode = 0o755
            archive.addfile(info, io.BytesIO(data))
    code = '''import json,os,pathlib,shutil,subprocess,sys
name=pathlib.Path(sys.argv[0]).name
with open(os.environ['TEST_CALLS'],'a') as f:
    f.write(json.dumps([name,*sys.argv[1:]])+'\\n')
if name=='curl':
    if os.getenv('TEST_DOWNLOAD_FAIL'): sys.exit(23)
    url=next(a for a in sys.argv if a.startswith('https:'))
    plugin='tmux-resurrect' if '/tmux-resurrect/' in url else 'tmux-continuum'
    shutil.copyfile(pathlib.Path(os.environ['TEST_ARCHIVES'])/(plugin+'.tar.gz'),sys.argv[sys.argv.index('--output')+1])
elif name=='getent':
    print('test:x:1000:1000:test:'+os.environ.get('TEST_ACCOUNT_HOME','/unrelated-home')+':/bin/bash')
elif name=='tmux': sys.exit(1)
elif name=='loginctl' and os.getenv('TEST_LINGER_SUDO'): sys.exit(1)
elif name=='sudo':
    env=dict(os.environ);env.pop('TEST_LINGER_SUDO',None)
    sys.exit(subprocess.run(sys.argv[1:],env=env).returncode)
'''
    for name in ('curl', 'getent', 'tmux', 'systemctl', 'loginctl', 'sudo', 'nm-online'):
        script = mock / name
        script.write_text(f'#!{sys.executable}\n' + code)
        script.chmod(0o755)
    env = dict(os.environ, PATH=f'{mock}:' + os.environ['PATH'], TEST_CALLS=str(log),
               TEST_ARCHIVES=str(archives))

    def install(home, *args, active=False, fail=False, extra=None):
        log.write_text('')
        current = dict(env)
        if active:
            current['TEST_ACCOUNT_HOME'] = str(home)
        if extra:
            current.update(extra)
        result = subprocess.run([BASH, str(ROOT / 'server/install.sh'), '--source', str(ROOT),
                                 '--home', str(home), *args], env=current,
                                text=True, capture_output=True, timeout=30)
        assert (result.returncode != 0) == fail, result.stdout + result.stderr
        return [json.loads(line) for line in log.read_text().splitlines()]

    home = root / 'staged'
    calls = install(home)
    assert not any(c[0] in ('systemctl', 'loginctl', 'sudo') for c in calls)
    for name in ('codex', 'pi', 'omp', 'opencode', 'tmux-session', 'tmux-agent-resume'):
        assert os.access(home / '.local/bin' / name, os.X_OK), name
    assert (home / '.local/lib/orgm-tmux/agents.py').read_bytes() == (ROOT / 'nixos/tmux/agents.py').read_bytes()
    assert (home / '.local/lib/orgm-tmux/hooks/opencode-session.mjs').is_file()
    assert 'tmux-session' in (home / '.config/tmux/plugins.conf').read_text()
    for name in ('tmux-session.service', 'tmux-session-save.service', 'tmux-session-save.timer'):
        unit = (home / '.config/systemd/user' / name).read_text()
        assert '/nix/store' not in unit and '# ORGM portable' in unit
    before = snapshot(home)
    log.write_text('')
    result = subprocess.run([str(home / '.local/bin/tmux-session'), 'wait-network'],
                            env=dict(env, HOME=str(home)), capture_output=True, text=True, timeout=5)
    assert result.returncode == 0, result.stderr
    calls = [json.loads(line) for line in log.read_text().splitlines()]
    assert ['nm-online', '--quiet', '--timeout=30'] in calls
    assert snapshot(home) == before
    install(home)
    assert snapshot(home) == before, 'reinstall must preserve idempotence'
    calls = install(home, '--dry-run', active=True)
    assert snapshot(home) == before
    assert not any(c[0] in ('systemctl', 'loginctl', 'sudo') for c in calls)

    failed = root / 'failed'
    install(failed, fail=True, extra={'TEST_DOWNLOAD_FAIL': '1'})
    assert not failed.exists(), 'failed staging must not touch HOME'
    protected = root / 'protected'
    path = protected / '.local/lib/orgm-tmux/hooks/pi-session.mjs'
    path.parent.mkdir(parents=True)
    path.symlink_to('/nix/store/protected-pi-hook')
    before = snapshot(protected)
    install(protected, fail=True)
    assert snapshot(protected) == before, 'new destinations must respect Nix ownership'

    only = root / 'tmux-only'
    only.mkdir()
    (only / '.bashrc').write_text('# keep my shell\n')
    install(only, '--tmux-only')
    assert (only / '.bashrc').read_text() == '# keep my shell\n'
    assert (only / '.local/bin/pi').is_file() and not (only / '.local/bin/codex-install').exists()

    if Path('/run/systemd/system').is_dir():
        active = root / 'active'
        calls = install(active, active=True)
        assert any(c[:2] == ['loginctl', 'enable-linger'] for c in calls)
        assert ['systemctl', '--user', 'enable', '--now', 'tmux-session.service', 'tmux-session-save.timer'] in calls
        assert ['systemctl', '--user', 'start', 'tmux-session-save.service'] in calls
        calls = install(active, '--no-autostart', active=True)
        assert not any(c[0] in ('systemctl', 'loginctl', 'sudo') for c in calls)
        calls = install(active, active=True, extra={'TEST_LINGER_SUDO': '1'})
        assert any(c[:3] == ['sudo', 'loginctl', 'enable-linger'] for c in calls)
        calls = install(active, '--no-plugins', active=True)
        assert ['systemctl', '--user', 'disable', '--now', 'tmux-session-save.timer', 'tmux-session.service'] in calls
    print('PASS: portable resources, alternate HOME isolation, idempotence, dry-run, failed staging, Nix ownership, boot activation and sudo fallback')
