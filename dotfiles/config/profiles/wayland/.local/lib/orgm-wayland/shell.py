#!/usr/bin/env python3
"""Sway IPC/menu adapter, with an optional preloaded Quickshell service."""
import configparser
import fcntl
import hashlib
import json
import os
from pathlib import Path
import random
import re
import select
import shutil
import signal
import stat
import subprocess
import sys
import tempfile
import time
import uuid


IMAGE_SUFFIXES = ('.avif', '.bmp', '.gif', '.jpg', '.jpeg', '.png', '.webp')
VIDEO_SUFFIXES = ('.mp4', '.mkv', '.webm', '.mov', '.m4v', '.avi')
MEDIA_SUFFIXES = IMAGE_SUFFIXES + VIDEO_SUFFIXES
COMPOSITOR = globals().get('COMPOSITOR', 'sway')

def wallpaper_state():
    if COMPOSITOR == 'hyprland':
        return Path(os.environ.get('XDG_STATE_HOME', Path.home()/'.local/state'))/'hypr-wallpaper/current'
    return Path(os.environ.get('XDG_CONFIG_HOME', Path.home()/'.config'))/'sway/wallpaper'



def run(*args, **kwargs):
    return subprocess.run(args, check=True, **kwargs)


def ipc(command):
    if command == "exit":
        # Sway closes its IPC connection while exiting, before replying.
        subprocess.run(["swaymsg", "exit"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return
    result = run("swaymsg", "-r", command, capture_output=True, text=True)
    replies = json.loads(result.stdout)
    if not all(reply.get("success", False) for reply in replies):
        raise RuntimeError(str(replies))


def query(kind):
    return json.loads(run("swaymsg", "-r", "-t", kind, capture_output=True, text=True).stdout)


def windows(node=None):
    if node is None:
        node = query("get_tree")
    if node.get("app_id") or node.get("window"):
        yield node
    for child in node.get("nodes", []) + node.get("floating_nodes", []):
        yield from windows(child)


def pick(prompt, labels, index=False):
    args = [str(Path.home()/".local/bin/orgm-rofi"), "--compositor", COMPOSITOR, "-dmenu", "-i", "-p", prompt]
    if index:
        args += ["-format", "i", "-no-custom"]
    result = subprocess.run(args, input="\n".join(labels), capture_output=True, text=True)
    return result.stdout.strip() if result.returncode == 0 else ""


def clean(value):
    return " ".join(str(value).split())


def choose_window(action="focus"):
    items = list(windows())
    selected = pick("Ventanas", [clean(w.get("name") or w.get("app_id") or "Ventana") for w in items], True)
    if selected.isdecimal() and int(selected) < len(items):
        ipc(f"[con_id={int(items[int(selected)]['id'])}] {action}")


def power(action=None, *, confirmed=False):
    if action is None:
        handled, selected = graphical_selection(dict(kind='power', **menu_context()))
        if handled:
            if selected in ('Bloquear', 'Ahorro', 'Suspender', 'Cerrar sesión', 'Reiniciar', 'Apagar'):
                power(selected, confirmed=True)
            return
    action = action or pick("Sesión", ["Bloquear", "Ahorro", "Suspender", "Cerrar sesión", "Reiniciar", "Apagar"])
    if action == "Bloquear":
        run("orgm-qylock", "lock")
    elif action == "Ahorro":
        # Monitors off without locking or sleeping; long jobs keep running.
        run("orgm-ahorro", "on")
    elif action == "Suspender":
        run("orgm-qylock", "lock")
        run("systemctl", "suspend")
    elif action in ("Cerrar sesión", "Reiniciar", "Apagar"):
        if not confirmed and pick(action, ["Cancelar", "Confirmar"]) != "Confirmar":
            return
        if action == "Cerrar sesión":
            ipc("exit")
        else:
            run("systemctl", "reboot" if action == "Reiniciar" else "poweroff")


def wallpaper_ipc_path(path):
    # Sway's `output bg` calls wordexp() even after IPC quotes are stripped.
    # Never expose shell/glob characters to it. Keep private aliases alive for
    # swaybg's asynchronous startup and later output hotplug/restarts.
    if re.fullmatch(r'/[a-zA-Z0-9/_.-]+', str(path)):
        return path
    runtime = Path(os.environ.get('XDG_RUNTIME_DIR', f'/run/user/{os.getuid()}'))
    if not runtime.is_dir() or not re.fullmatch(r'/[a-zA-Z0-9/_.-]+', str(runtime)):
        runtime = Path('/tmp')
    directory = runtime / f'orgm-sway-wallpapers-{os.getuid()}'
    directory.mkdir(mode=0o700, exist_ok=True)
    info = directory.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) != 0o700:
        raise ValueError('El directorio de aliases de fondos no es privado y propio')
    alias = directory / hashlib.sha256(os.fsencode(path)).hexdigest()
    try:
        alias.symlink_to(path)
    except FileExistsError:
        if not alias.is_symlink() or alias.lstat().st_uid != os.getuid() or alias.readlink() != path:
            raise ValueError('El alias del fondo ya existe con otro destino')
    return alias


def wallpaper_tool(name):
    binary = shutil.which(name)
    fallback = Path(os.environ.get('XDG_STATE_HOME', Path.home()/'.local/state')) / 'orgm-sway-wallpaper-tools/bin' / name
    if binary:
        return binary
    if fallback.is_file() and os.access(fallback, os.X_OK):
        return str(fallback)
    raise RuntimeError(f'Falta {name}; reconstruye el perfil del escritorio para instalar las herramientas de fondos')


def wallpaper_preview(value, *, thumbnail=False):
    path = Path(value).expanduser().resolve(strict=True)
    if path.suffix.lower() not in VIDEO_SUFFIXES:
        if path.suffix.lower() not in IMAGE_SUFFIXES:
            raise ValueError('Formato de fondo no admitido')
        # Applying a still wallpaper must keep its original resolution. Only
        # the picker's decode-error fallback requests a bounded thumbnail.
        if not thumbnail:
            return path
    info = path.stat()
    key = hashlib.sha256(os.fsencode(path) + f':{info.st_mtime_ns}:{info.st_size}:v1'.encode()).hexdigest()
    cache = Path(os.environ.get('XDG_CACHE_HOME', Path.home()/'.cache')) / 'orgm-sway-wallpapers'
    cache.mkdir(parents=True, exist_ok=True, mode=0o700)
    preview = cache / (key + '.png')
    if not preview.is_file():
        # Unique staging files allow simultaneous carousel/lock requests.
        with tempfile.TemporaryDirectory(prefix='preview-', dir=cache) as directory:
            temporary = Path(directory)/'frame.png'
            result = run(wallpaper_tool('ffmpeg'), '-nostdin', '-v', 'error', '-i', str(path),
                         '-map', '0:v:0', '-frames:v', '1', '-vf', 'scale=1200:800:force_original_aspect_ratio=decrease',
                         '-threads', '1', '-update', '1', str(temporary),
                         capture_output=True, text=True, timeout=20)
            if not temporary.is_file() or not temporary.stat().st_size:
                raise RuntimeError('El archivo no contiene una imagen válida: ' + result.stderr.strip())
            temporary.replace(preview)
    return preview


def stop_wallpaper_video(unit):
    # Never accept arbitrary units, PIDs or process names from saved state.
    if re.fullmatch(r'orgm-sway-video-[0-9a-f]{32}\.service', unit):
        result = subprocess.run(['systemctl', '--user', 'stop', unit],
                                stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
        # Transient units are collected on logout/crash. A stale saved owner is
        # harmless; a still-active player that cannot be stopped is not.
        if result.returncode and subprocess.run(
                ['systemctl', '--user', 'is-active', '--quiet', unit]).returncode == 0:
            raise RuntimeError('No se pudo detener el fondo anterior: ' + result.stderr.strip())


def is_session_wallpaper_process(process):
    # Compare the real executable (Nix wrappers included), UID and Wayland
    # endpoint. Never match command-line substrings or another compositor.
    display = os.environ.get('WAYLAND_DISPLAY')
    runtime = os.environ.get('XDG_RUNTIME_DIR')
    if not display or not runtime:
        return False
    try:
        if process.stat().st_uid != os.getuid():
            return False
        if (process/'exe').resolve(strict=True).name not in (
                'swaybg', '.swaybg-wrapped', 'mpvpaper', '.mpvpaper-wrapped'):
            return False
        environment = dict(entry.split(b'=', 1) for entry in (process/'environ').read_bytes().split(b'\0') if b'=' in entry)
        return (environment.get(b'WAYLAND_DISPLAY') == os.fsencode(display)
                and environment.get(b'XDG_RUNTIME_DIR') == os.fsencode(runtime))
    except (OSError, ValueError):
        return False


def stop_session_wallpaper_players():
    # This also collects stale/manual duplicates not present in the unit file.
    # pidfds prevent PID-reuse races, and waiting avoids transient overlap.
    if not os.environ.get('WAYLAND_DISPLAY') or not os.environ.get('XDG_RUNTIME_DIR'):
        return
    for process in Path('/proc').iterdir():
        if not process.name.isdecimal() or not is_session_wallpaper_process(process):
            continue
        try:
            descriptor = os.pidfd_open(int(process.name))
        except ProcessLookupError:
            continue
        try:
            if not is_session_wallpaper_process(process):
                continue
            poller = select.poll()
            poller.register(descriptor, select.POLLIN)
            try:
                signal.pidfd_send_signal(descriptor, signal.SIGTERM)
                if not poller.poll(2000):
                    signal.pidfd_send_signal(descriptor, signal.SIGKILL)
                    if not poller.poll(2000):
                        raise RuntimeError('El proceso de fondo anterior no termina: ' + process.name)
            except ProcessLookupError:
                pass
        finally:
            os.close(descriptor)


def game_mode_active():
    state = Path(os.environ.get('XDG_STATE_HOME', Path.home()/'.local/state')) / 'orgm-sway/game-mode.json'
    try:
        return json.loads(state.read_text()).get('enabled') is True
    except (OSError, ValueError, AttributeError):
        return False


def hide_wallpaper():
    config = Path(os.environ.get('XDG_CONFIG_HOME', Path.home()/'.config')) / 'sway'
    config.mkdir(parents=True, exist_ok=True)
    with (config/'wallpaper.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        owner = config/'wallpaper-video-unit'
        if owner.is_file():
            stop_wallpaper_video(owner.read_text().strip())
        stop_session_wallpaper_players()
        ipc('output * bg #000000 solid_color')
        owner.write_text('\n')


def apply_wallpaper_backend(path, preview):
    if game_mode_active():
        ipc('output * bg #000000 solid_color')
        return ''
    if path.suffix.lower() in VIDEO_SUFFIXES:
        return start_wallpaper_video(path)
    ipc('output * bg ' + json.dumps(str(wallpaper_ipc_path(preview)), ensure_ascii=False) + ' fill')
    return ''


def wallpaper_nvidia_offload():
    # The wrapper may exist while the GPU is powered off, absent or bound to
    # VFIO. Probe the driver with a bounded wait, not just the executable name.
    if os.environ.get('ORGM_SWAY_WALLPAPER_OFFLOAD') == '0':
        return None
    wrapper = shutil.which('nvidia-offload')
    probe = shutil.which('nvidia-smi')
    if not wrapper or not probe:
        return None
    try:
        result = subprocess.run([probe, '-L'], capture_output=True, text=True, timeout=2)
    except (OSError, subprocess.SubprocessError):
        return None
    return wrapper if result.returncode == 0 and result.stdout.startswith('GPU ') else None


def start_wallpaper_video(path):
    binary = wallpaper_tool('mpvpaper')
    offload = wallpaper_nvidia_offload()
    launchers = [[offload, binary], [binary]] if offload else [[binary]]
    for launcher in launchers:
        unit = 'orgm-sway-video-' + uuid.uuid4().hex + '.service'
        command = ['systemd-run', '--user', '--quiet', '--collect', '--service-type=exec',
                   '--expand-environment=no',
                   '--unit=' + unit, '--property=PartOf=sway-session.target',
                   '--property=KillMode=control-group', '--property=TimeoutStopSec=2s']
        for key in ('WAYLAND_DISPLAY', 'XDG_RUNTIME_DIR'):
            if key in os.environ:
                command.append('--setenv=' + key + '=' + os.environ[key])
        try:
            run(*command, '--', *launcher, '-o', 'no-config no-audio loop-file=inf panscan=1', 'ALL', str(path))
            # Type=exec catches exec failures; allow extra GPU initialization
            # time for offload before checking immediate driver/display errors.
            time.sleep(0.6 if len(launcher) == 2 else 0.3)
            run('systemctl', '--user', 'is-active', '--quiet', unit)
        except (OSError, subprocess.CalledProcessError):
            # Fully stop the failed attempt before retrying on the default GPU.
            stop_wallpaper_video(unit)
            continue
        return unit
    raise RuntimeError('No se pudo iniciar mpvpaper; consulta journalctl --user -u ' + unit)


def set_wallpaper(value, record=True):
    path = Path(value).expanduser().resolve(strict=True)
    if not path.is_file() or path.suffix.lower() not in MEDIA_SUFFIXES:
        raise ValueError('Formato de fondo no admitido')
    preview = wallpaper_preview(path)
    # Check dependencies before stopping a working background.
    if path.suffix.lower() in VIDEO_SUFFIXES and not game_mode_active():
        wallpaper_tool('mpvpaper')
    state = wallpaper_state()
    state.parent.mkdir(parents=True, exist_ok=True)
    # Serialize restore, profile changes and carousel requests, but release before
    # calling the profile recorder (which owns a different, reentrant lock).
    with (state.parent/'wallpaper.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        owner = state.parent/'wallpaper-video-unit'
        previous = owner.read_text().strip() if owner.is_file() else ''
        previous_path = Path(state.read_text().strip()) if state.is_file() else None
        if previous:
            stop_wallpaper_video(previous)  # systemctl waits for the whole cgroup
        stop_session_wallpaper_players()  # swaybg and any unrecorded mpvpaper
        owner.write_text('\n')
        try:
            unit = apply_wallpaper_backend(path, preview)
        except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
            # Stop-before-start means a failed replacement needs an explicit
            # rollback. Restore without recursion, profile recording or overlap.
            if previous_path and previous_path.is_file() and previous_path.suffix.lower() in MEDIA_SUFFIXES:
                try:
                    stop_session_wallpaper_players()
                    restored = apply_wallpaper_backend(previous_path, wallpaper_preview(previous_path))
                    owner.write_text(restored + '\n')
                except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as rollback:
                    raise RuntimeError(f'{error}; tampoco se pudo restaurar el fondo anterior: {rollback}') from error
            raise
        # Keep original media for profiles; the locker receives only an image.
        for target, text in ((state, str(path)), (state.parent/'wallpaper-preview', str(preview)), (owner, unit)):
            temporary = target.with_name(target.name + '.tmp')
            temporary.write_text(text + '\n')
            temporary.replace(target)
    helper = Path.home()/'.local/bin/orgm-visual-profile'
    if record and helper.is_file() and os.environ.get('ORGM_VISUAL_PROFILE_SKIP_RECORD') != '1':
        run(str(helper), 'record-wallpaper', str(path))


def wallpaper_directories():
    return (Path.home()/'Pictures/Wallpapers', Path.home()/'Pictures/wallpapers',
            Path.home()/'Wallpapers', Path.home()/'.local/share/wallpapers')


def wallpaper_images(directory):
    return [p.resolve() for p in directory.rglob('*')
            if p.is_file() and p.suffix.lower() in MEDIA_SUFFIXES]


def random_wallpaper(directory):
    candidates = wallpaper_images(Path(directory).expanduser())
    if not candidates:
        # New visual profiles start with an empty folder: use shared wallpapers.
        candidates = [p for shared in wallpaper_directories() for p in wallpaper_images(shared)]
    if not candidates:
        raise ValueError('No hay imágenes ni videos en el perfil ni en las carpetas de fondos')
    state = wallpaper_state()
    current = state.read_text().strip() if state.is_file() else ''
    candidates = sorted(set(candidates))
    alternatives = [p for p in candidates if str(p) != current]
    set_wallpaper(random.choice(alternatives or candidates))


def visual_profile_state():
    return Path(os.environ.get('ORGM_VISUAL_PROFILE_STATE_DIR',
                str(Path(os.environ.get('XDG_STATE_HOME', Path.home()/'.local/state')) / 'orgm-visual-profile')))


def current_visual_profile():
    current = visual_profile_state()/'current'
    profile = current.read_text().strip() if current.is_file() else 'orgm'
    return profile if profile in ('slc', 'orgm', 'osmar') else 'orgm'


def saved_profile_wallpaper(profile):
    saved = visual_profile_state()/'profiles'/profile/'wallpaper'
    if saved.is_file() and (value := saved.read_text().strip()):
        path = Path(value).expanduser()
        if path.is_file() and path.suffix.lower() in MEDIA_SUFFIXES:
            return path.resolve()
    return None


def menu_colors():
    config = Path(os.environ.get('XDG_CONFIG_HOME', Path.home()/'.config'))
    colors = dict(bg='#080808', surface='#202020', fg='#f5f5f5', muted='#b8b8b8',
                  accent='#8ab4f8', error='#ff8a8a')
    palette = config / ('waybar-hypr/orgm-current.css' if COMPOSITOR == 'hyprland' else 'waybar/orgm-current.css')
    if palette.is_file():
        definitions = dict(re.findall(r'^@define-color\s+(\w+)\s+(#[0-9a-fA-F]{6});\s*$',
                                      palette.read_text(), re.MULTILINE))
        for name, key in dict(bg='base', surface='surface0', fg='text', muted='overlay0',
                              accent='blue', error='red').items():
            colors[name] = definitions.get(key, colors[name])
    return colors


def menu_context():
    try:
        output = next((w.get('output', '') for w in query('get_workspaces') if w.get('focused')), '')
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError):
        output = ''
    return dict(screen=output, colors=menu_colors())


def wallpaper_catalog():
    config = Path(os.environ.get('XDG_CONFIG_HOME', Path.home()/'.config'))
    profile = current_visual_profile()
    pictures = Path(os.environ.get('ORGM_VISUAL_PROFILE_PICTURES_ROOT', Path.home()/'Pictures'))
    directories = [pictures/profile]
    images = set()
    for directory in directories:
        try:
            images.update(wallpaper_images(directory))
        except OSError:
            continue
    # A saved assignment belongs to this profile even when stored elsewhere.
    if saved := saved_profile_wallpaper(profile):
        images.add(saved)
    state = wallpaper_state()
    current = state.read_text().strip() if state.is_file() else ''
    return dict(profile=profile, current=current, **menu_context(),
                directories=[str(p) for p in directories], backend=str(Path(ENTRYPOINT).resolve()),
                items=[dict(path=str(p), url=p.as_uri(), name=clean(p.name),
                            kind='video' if p.suffix.lower() in VIDEO_SUFFIXES else 'image')
                       for p in sorted(images, key=lambda p: (p.name.casefold(), str(p)))])


def profile_catalog():
    items = []
    for profile in ('slc', 'orgm', 'osmar'):
        path = saved_profile_wallpaper(profile)
        preview = ''
        if path:
            try:
                preview = wallpaper_preview(path).as_uri()
            except (OSError, ValueError, RuntimeError, subprocess.SubprocessError):
                pass
        items.append(dict(id=profile, name=profile.upper(), preview=preview))
    return dict(kind='profiles', current=current_visual_profile(), items=items, **menu_context())


def profiles():
    handled, selected = graphical_selection(profile_catalog())
    if not handled:
        selected = pick('Perfil visual', ['slc', 'orgm', 'osmar'])
    if selected in ('slc', 'orgm', 'osmar'):
        run(str(Path.home()/'.local/bin/orgm-visual-profile'), 'set', selected,
            env=dict(os.environ, ORGM_VISUAL_PROFILE_BACKEND=COMPOSITOR, ORGM_VISUAL_PROFILE_KEEP_WAYBAR='1'))


def launcher_theme():
    colors = menu_colors()
    values = dict(bg=colors['bg'], **{'bg-panel': colors['bg']+'eb',
                  'surface-soft': colors['surface']+'99', 'fg': colors['fg'],
                  'muted': colors['muted'], 'accent': colors['accent'],
                  'accent-soft': colors['accent']+'2e', 'accent-line': colors['accent']+'99',
                  'red': colors['error'], 'red-soft': colors['error']+'2e',
                  'outline': colors['fg']+'1f'})
    return '* {\n'+'\n'.join(f'    {key}: {value};' for key, value in values.items())+'\n}'


def quickshell_binary():
    binary = shutil.which('qs')
    if binary:
        return binary
    fallback = Path(os.environ.get('XDG_STATE_HOME', Path.home()/'.local/state')) / 'orgm-sway-wallpaper-quickshell/bin/qs'
    return str(fallback) if fallback.is_file() and os.access(fallback, os.X_OK) else None


def resident_graphical_menu(binary, config, catalog, data, done, result):
    daemon = config/'daemon.qml'
    if not daemon.is_file():
        return None
    data.write_text(json.dumps(dict(catalog, kind=catalog.get('kind', 'wallpaper')), ensure_ascii=False))
    data.chmod(0o600)
    try:
        reply = subprocess.run([binary, '--path', str(daemon), 'ipc', 'call', 'menu', 'request',
                                str(data), str(result) if result else '', str(done)],
                               capture_output=True, text=True, timeout=2)
    except (OSError, subprocess.SubprocessError):
        return None
    answer = reply.stdout.strip()
    if reply.returncode:
        return None
    if answer in ('busy', 'duplicate'):
        return True
    if not re.fullmatch(r'accepted:[1-9][0-9]*', answer):
        return None
    try:
        pidfd = os.pidfd_open(int(answer.partition(':')[2]))
    except OSError:
        return False
    try:
        next_check = time.monotonic()+2
        while not done.exists():
            if select.select([pidfd], [], [], .04)[0]:
                return done.is_file()
            if time.monotonic() >= next_check:
                # A QML hot reload can reset the request while keeping the same PID.
                try:
                    owner = subprocess.run([binary, '--path', str(daemon), 'ipc', 'call', 'menu',
                                            'owns', str(done)], capture_output=True, text=True, timeout=2)
                except (OSError, subprocess.SubprocessError):
                    return False
                if owner.returncode or owner.stdout.strip() != 'yes':
                    return done.is_file()
                next_check = time.monotonic()+2
        return True
    finally:
        os.close(pidfd)


def graphical_menu(catalog, *, entry=None, result=None):
    binary = quickshell_binary()
    config = Path(os.environ.get('XDG_CONFIG_HOME', Path.home()/'.config')) / 'quickshell/orgm-wallpapers'
    target = config/entry if entry else config
    if not binary or not (target if entry else config/'shell.qml').is_file():
        return False
    with tempfile.TemporaryDirectory(prefix='orgm-wallpapers-') as directory:
        data = Path(directory) / 'catalog.json'
        data.write_text(json.dumps(catalog, ensure_ascii=False))
        data.chmod(0o600)
        status = Path(directory) / 'status'
        resident = resident_graphical_menu(binary, config, catalog, data, status, result)
        if resident is not None:
            return resident
        with subprocess.Popen([binary, '--no-duplicate', '--path', str(target)],
                              env=dict(os.environ, ORGM_DESKTOP_COMPOSITOR=COMPOSITOR, ORGM_WALLPAPER_DATA=str(data),
                                       ORGM_WALLPAPER_STATUS=str(status),
                                       ORGM_MENU_RESULT=str(result) if result else '')) as process:
            deadline = time.monotonic() + 10
            while process.poll() is None and not status.exists() and time.monotonic() < deadline:
                time.sleep(0.05)
            if status.is_file() and status.read_text().strip() == 'ready':
                return process.wait() == 0
            if not status.exists() and process.poll() is not None:
                # --no-duplicate exits successfully without loading this catalog.
                return process.returncode == 0
            # A broken QML config must not remain resident or trap the keyboard.
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=2)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
            return False


def graphical_wallpaper_picker(catalog):
    return graphical_menu(catalog)


def graphical_selection(catalog):
    with tempfile.TemporaryDirectory(prefix='orgm-menu-') as directory:
        result = Path(directory)/'selection'
        handled = graphical_menu(catalog, entry='menus.qml', result=result)
        return handled, result.read_text().strip() if handled and result.is_file() else ''


def wallpaper(choose=False):
    state = wallpaper_state()
    if choose:
        catalog = wallpaper_catalog()
        if graphical_wallpaper_picker(catalog):
            return
        # Safe fallback for old generations or a failed QML startup.
        candidates = [item['path'] for item in catalog['items']]
        selected = pick("Fondo", candidates)
        if selected:
            set_wallpaper(selected)
        return
    if state.is_file():
        path = Path(state.read_text().strip())
        if path.is_file():
            set_wallpaper(path, record=False)


def screenshot(mode):
    args = ["grim"]
    if mode != "full":
        selected = subprocess.run(["slurp"], capture_output=True, text=True)
        if selected.returncode or not selected.stdout.strip():
            return
        args += ["-g", selected.stdout.strip()]
    image = run(*args, "-", capture_output=True).stdout
    run("swappy", "-f", "-", input=image)


def apply_appearance():
    settings = configparser.ConfigParser(interpolation=None)
    path = Path.home() / ".config/sway/appearance.ini"
    with path.open() as source:
        settings.read_file(source)
    appearance = settings["Appearance"]
    scheme = appearance["color-scheme"]
    if scheme not in ("default", "prefer-dark", "prefer-light"):
        raise ValueError("Invalid color-scheme in " + str(path))
    thumbnails = settings.get('Files', 'show-image-thumbnails', fallback='always')
    if thumbnails not in ('always', 'local-only', 'never'):
        raise ValueError('Invalid show-image-thumbnails in ' + str(path))
    # GTK 3 settings.ini is insufficient for libadwaita and the Settings portal.
    # dconf does not require schema lookup in the compositor's environment.
    for key in ("color-scheme", "gtk-theme", "icon-theme"):
        value = appearance.get(key, "Colloid-Dark") if key == "icon-theme" else appearance[key]
        run("dconf", "write", "/org/gnome/desktop/interface/" + key, json.dumps(value))
    # Nautilus defaults to local-only, which hides previews in Nextcloud/WebDAV.
    # Keep its existing size limit and global thumbnailer policy unchanged.
    run('dconf', 'write', '/org/gnome/nautilus/preferences/show-image-thumbnails',
        json.dumps(thumbnails))
    helper = Path.home()/'.local/bin/orgm-visual-profile'
    if helper.is_file():
        # Reloading the compositor must preserve Caffeine and click processes
        # owned by Waybar; its CSS watcher can refresh the palette in place.
        run(str(helper), 'apply', env=dict(os.environ, ORGM_VISUAL_PROFILE_BACKEND='sway',
                                         ORGM_VISUAL_PROFILE_KEEP_WAYBAR='1'))


def main(args):
    command = args[0] if args else "menu"
    if command == "appearance":
        apply_appearance()
    elif command == "windows":
        run(str(Path(ENTRYPOINT).with_name('orgm-sway-desktop')), 'windows', *args[1:])
    elif command in ('audio', 'clipboard', 'control'):
        run(str(Path(ENTRYPOINT).with_name('orgm-sway-desktop')), command)
    elif command == "kill-window":
        choose_window("kill")
    elif command == "obsidian":
        for window in windows():
            app = window.get("app_id") or window.get("window_properties", {}).get("class", "")
            if "obsidian" in app.lower():
                ipc(f"[con_id={int(window['id'])}] focus")
                return
        subprocess.Popen(["obsidian"], start_new_session=True)
    elif command == "move-workspace":
        current = next(w for w in query("get_workspaces") if w.get("focused"))
        number = int(current["num"])
        destination = (number - 1 + (-1 if args[1] == "prev" else 1)) % 10 + 1
        ipc(f"move container to workspace number {destination}; workspace number {destination}")
    elif command in ("power", "logout"):
        power("Cerrar sesión" if command == "logout" else None)
    elif command == 'profiles':
        profiles()
    elif command == 'launcher-theme':
        print(launcher_theme())
    elif command == 'wallpaper-set':
        set_wallpaper(args[1])
    elif command == 'wallpaper-preview':
        print(wallpaper_preview(args[1], thumbnail=True).as_uri())
    elif command == 'wallpaper-random':
        random_wallpaper(args[1])
    elif command in ("wallpaper", "wallpaper-pick"):
        wallpaper(command == "wallpaper-pick")
    elif command == "screenshot":
        screenshot(args[1] if len(args) > 1 else "region")
    elif command == "help":
        config = Path.home() / ".config/sway/config"
        pick("Atajos", [line.removeprefix("bindsym ") for line in config.read_text().splitlines() if line.startswith("bindsym ")])
    elif command == "menu":
        run(str(Path(ENTRYPOINT).with_name('orgm-sway-desktop')), 'control')
    elif command == "menu-fallback":
        commands = {
            "Aplicaciones": ["sway-app-launcher"],
            "Wi-Fi / red": ["kitty", "--class", "nmtui", "-e", "nmtui"],
            "Bluetooth": ["kitty", "--class", "bluetui", "-e", "bluetui"],
            "Audio": ["pavucontrol"],
            "Notificaciones": ["swaync-client", "--toggle-panel", "--skip-wait"],
            "Pantallas": ["nwg-displays", "-o", str(Path.home()/".config/sway/outputs.conf"), "-n", "10"],
            "Cuentas en línea": ["gnome-online-accounts-gtk"],
            "Monitor del sistema": ["gnome-system-monitor"],
            "Archivos": ["nautilus", "--new-window"],
            "Perfil visual": ["orgm-sway", "profiles"],
            "Fondo de pantalla": ["orgm-sway", "wallpaper-pick"],
            "Inicio y bloqueo": ["orgm-qylock", "themes"],
            "Sesión / suspender": ["orgm-sway", "power"],
        }
        selected = pick("Control", list(commands))
        if selected in commands:
            subprocess.Popen(commands[selected], start_new_session=True)
    else:
        raise ValueError("Unknown action: " + command)


if __name__ == "__main__":
    try:
        main(sys.argv[1:])
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print("orgm-sway:", error, file=sys.stderr)
        sys.exit(1)
