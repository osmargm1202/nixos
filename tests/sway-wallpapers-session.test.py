#!/usr/bin/env python3
"""Opt-in real QML test. Uses a private Sway compositor, HOME and D-Bus.
Run with ORGM_TEST_QS=/path/to/quickshell/bin/qs python3 tests/sway-wallpapers-session.test.py.
Set ORGM_TEST_POINTER_KEEPER to the tests/helpers/sway-pointer-keeper.nix binary
for real wheel/click regression tests. ORGM_TEST_WALLPAPER_UI selects an alternate
QML directory for before/after comparisons.
ORGM_TEST_VIDEO_TOOLS=/path/to/bin enables real WebP/video/restore tests. These
create uniquely named transient units on the user manager, always cleaned up.
Never sends input or applies wallpapers to the user's compositor.
"""
import json
import os
from pathlib import Path
import shutil
import signal
import struct
import subprocess
import tempfile
import time
import zlib

ROOT = Path(__file__).resolve().parents[1]
QS = os.environ.get('ORGM_TEST_QS') or shutil.which('qs')
if not QS:
    raise SystemExit('Set ORGM_TEST_QS to the Quickshell 0.3 package binary')
HOME = Path(tempfile.mkdtemp(prefix='sway-wallpaper-picker-'))
runtime = HOME/'runtime'
runtime.mkdir(mode=0o700)
config = HOME/'.config'
ui_source = Path(os.environ.get('ORGM_TEST_WALLPAPER_UI',
    str(ROOT/'dotfiles/config/profiles/wayland/.config/quickshell/orgm-wallpapers')))
shutil.copytree(ui_source, config/'quickshell/orgm-wallpapers')
bin_dir = HOME/'bin'
bin_dir.mkdir()
(bin_dir/'qs').symlink_to(Path(QS).resolve())
real_swaymsg = shutil.which('swaymsg')
# Only this private test's background commands can be deliberately rejected.
(bin_dir/'swaymsg').write_text('#!/usr/bin/env python3\nimport os,sys,json\n'
    f'if os.path.exists({str(HOME/"fail-background")!r}) and sys.argv[-1].startswith("output * bg "):\n'
    ' print(json.dumps([dict(success=False,error="Injected private background failure")]))\n'
    ' sys.exit(0)\n'
    f'os.execv({real_swaymsg!r}, [{real_swaymsg!r}]+sys.argv[1:])\n')
(bin_dir/'swaymsg').chmod(0o755)
profile = HOME/'Pictures/slc'
profile.mkdir(parents=True)

def png(path, phase):
    w, h = 640, 400
    pixels = b''.join(b'\0' + bytes(v for x in range(w) for v in
        ((x//3 + phase) % 256, (y//2 + phase) % 256, (x//4 + y//3 + phase) % 256))
        for y in range(h))
    def chunk(kind, data):
        return struct.pack('!I', len(data)) + kind + data + struct.pack('!I', zlib.crc32(kind+data))
    path.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('!2I5B', w,h,8,2,0,0,0))
                     + chunk(b'IDAT', zlib.compress(pixels)) + chunk(b'IEND', b''))

images = [profile/'A azul.png', profile/'B verde.png', profile/'C "ñ$(touch PWNED)" : noche  #.png']
for i, image in enumerate(images):
    png(image, i*60)
state = config/'sway/wallpaper'
state.parent.mkdir(parents=True)
state.write_text(str(images[0])+'\n')
profile_state = HOME/'.local/state/orgm-visual-profile/current'
profile_state.parent.mkdir(parents=True)
profile_state.write_text('slc\n')
(config/'waybar').mkdir()
(config/'waybar/orgm-current.css').write_text('@define-color base #071422;\n@define-color blue #71b7ff;\n')
(HOME/'sway.conf').write_text('output HEADLESS-1 mode 1920x1080 pos 0 0\noutput HEADLESS-2 mode 1280x720 pos 1920 0\n'
    'font pango:monospace 10\ndefault_border none\n')
env = dict(os.environ, HOME=str(HOME), XDG_CONFIG_HOME=str(config), XDG_CACHE_HOME=str(HOME/'.cache'),
           XDG_STATE_HOME=str(HOME/'.local/state'), XDG_DATA_HOME=str(HOME/'.local/share'),
           XDG_RUNTIME_DIR=str(runtime), PATH=str(bin_dir)+os.pathsep+os.environ['PATH'],
           XDG_CURRENT_DESKTOP='sway', QT_QPA_PLATFORM='wayland', WLR_BACKENDS='headless',
           WLR_HEADLESS_OUTPUTS='2', WLR_RENDERER='gles2', WLR_RENDERER_ALLOW_SOFTWARE='1')
for key in ('DISPLAY','WAYLAND_DISPLAY','SWAYSOCK','DBUS_SESSION_BUS_ADDRESS','WAYLAND_SOCKET',
            'ORGM_VISUAL_PROFILE_STATE_DIR','ORGM_VISUAL_PROFILE_PICTURES_ROOT','QS_CONFIG_PATH','QS_CONFIG_NAME'):
    env.pop(key, None)
intel = Path('/dev/dri/by-path/pci-0000:00:02.0-render')
if intel.exists():
    env['WLR_RENDER_DRM_DEVICE'] = str(intel.resolve())
log = (HOME/'session.log').open('w')
sway = subprocess.Popen(['dbus-run-session','--','sh','-c',
    'printf "%s" "$DBUS_SESSION_BUS_ADDRESS" > "$1"; shift; exec "$@"', '_', str(HOME/'bus'),
    shutil.which('sway'), '-c', str(HOME/'sway.conf')], env=env, cwd=HOME, stdout=log, stderr=log, start_new_session=True)
children = []

def wait(probe, why):
    for _ in range(120):
        value = probe()
        if value:
            return value
        assert sway.poll() is None, 'Private Sway exited'
        time.sleep(.05)
    raise AssertionError('Timeout: '+why+'; logs in '+str(HOME))

def command(*args):
    return subprocess.run(args, env=env, capture_output=True, text=True, timeout=5)

def status():
    result = command(str(QS), '--path', str(config/'quickshell/orgm-wallpapers'), 'ipc', 'call', 'wallpaper', 'status')
    return json.loads(result.stdout) if result.returncode == 0 else None

def start():
    process = subprocess.Popen([str(ROOT/'dotfiles/config/profiles/sway/.local/bin/orgm-sway'), 'wallpaper-pick'],
        env=env, cwd=HOME, stdout=log, stderr=log, start_new_session=True)
    children.append(process)
    return process

def key(name):
    # IPC registers before Qt's first layer commit. Wait for the actual surface
    # and give the private seat's keyboard-enter event a dispatch round trip.
    wait(lambda: any(layer['namespace'] == 'orgm-wallpapers'
         for output in json.loads(command(real_swaymsg, '-r', '-t', 'get_outputs').stdout)
         for layer in output.get('layer_shell_surfaces', [])), 'layer surface before input')
    time.sleep(.2)
    result = command('wtype', '-k', name)
    assert result.returncode == 0, result.stderr
    time.sleep(.3)

try:
    env['SWAYSOCK'] = str(wait(lambda: next(iter(runtime.glob('sway-ipc.*.sock')), None), 'IPC'))
    env['DBUS_SESSION_BUS_ADDRESS'] = (HOME/'bus').read_text()
    env['WAYLAND_DISPLAY'] = wait(lambda: next((p.name for p in runtime.glob('wayland-*') if not p.name.endswith('.lock')),None),'Wayland')
    assert str(runtime) in env['SWAYSOCK']
    # Keep a keyboard capability present before Qt binds wl_seat (headless has none).
    keeper = subprocess.Popen(['wtype', '-s', '120000'], env=env, stdout=log, stderr=log, start_new_session=True)
    children.append(keeper)
    pointer_helper = os.environ.get('ORGM_TEST_POINTER_KEEPER')
    if pointer_helper:
        pointer = subprocess.Popen([pointer_helper], env=env, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            stderr=log, text=True, start_new_session=True)
        children.append(pointer)
        assert pointer.stdout.readline().strip() == 'ready'
    time.sleep(.15)
    command(real_swaymsg, 'focus output HEADLESS-2').check_returncode()
    p = start()
    data = wait(status, 'QML carousel mapping')
    assert data['count'] == 3 and data['profile'] == 'slc' and data['screen'] == 'HEADLESS-2', data
    assert data['selected'] == str(images[0]), data
    duplicate = start()
    assert duplicate.wait(timeout=5) == 0 and status()['selected'] == str(images[0])
    time.sleep(.6)
    command('grim', '-o', 'HEADLESS-2', str(HOME/'preview-1280.png')).check_returncode()
    key('Right')
    assert status()['selected'] == str(images[1])
    if pointer_helper:
        outputs = json.loads(command(real_swaymsg, '-r', '-t', 'get_outputs').stdout)
        rect = next(o['rect'] for o in outputs if o['name'] == 'HEADLESS-2')
        command(real_swaymsg, f"seat seat0 cursor set {rect['x']+640} {rect['y']+360}").check_returncode()
        time.sleep(.2)
        def wheel(axis, amount, kind='w'):
            pointer.stdin.write(f'{kind} {axis} {amount}\n')
            pointer.stdin.flush()
            assert pointer.stdout.readline().strip() == 'done'
        wheel(0, 1)
        time.sleep(.3)
        assert status()['selected'] == str(images[2]), ('wheel down over image', status())
        wheel(0, -1)
        time.sleep(.3)
        assert status()['selected'] == str(images[1]), ('wheel up over image', status())
        wheel(1, 1)
        time.sleep(.3)
        assert status()['selected'] == str(images[2]), ('horizontal wheel right', status())
        wheel(1, -1)
        time.sleep(.3)
        assert status()['selected'] == str(images[1]), ('horizontal wheel left', status())
        # High-resolution finger scroll must accumulate, not skip a card for
        # every tiny event. Reverse direction must remain responsive.
        wheel(0, 5, 'f')
        time.sleep(.04)
        assert status()['selected'] == str(images[1]), ('fractional finger scroll', status())
        wheel(0, 5, 'f')
        time.sleep(.15)
        assert status()['selected'] == str(images[2]), ('accumulated finger scroll', status())
        wheel(0, -10, 'f')
        time.sleep(.15)
        assert status()['selected'] == str(images[1]), ('reverse finger scroll', status())
        # Non-button-accepting wheel overlay must not swallow card clicks.
        command(real_swaymsg, f"seat seat0 cursor set {rect['x']+1030} {rect['y']+360}").check_returncode()
        command(real_swaymsg, 'seat seat0 cursor press button1').check_returncode()
        command(real_swaymsg, 'seat seat0 cursor release button1').check_returncode()
        time.sleep(.3)
        assert status()['selected'] == str(images[2]), ('side-card click passes through', status())
        print('PASS: real vertical/horizontal wheel, high-resolution finger scroll and side-card clicks', flush=True)
    else:
        print('SKIP: wheel tests need ORGM_TEST_POINTER_KEEPER in headless mode', flush=True)
    key('Escape')
    assert p.wait(timeout=5) == 0
    assert state.read_text().strip() == str(images[0])
    print('PASS: real QML, active monitor, saved image, arrows, duplicate prevention and cancellation', flush=True)

    command(real_swaymsg, 'focus output HEADLESS-1').check_returncode()
    p = start()
    wait(status, 'second mapping')
    key('Right')
    (HOME/'fail-background').touch()
    key('Return')
    data = wait(lambda: (s if (s := status()) and s['error'] else None), 'visible backend error')
    assert not data['busy'] and p.poll() is None, data
    assert state.read_text().strip() == str(images[0])
    command('grim','-o','HEADLESS-1',str(HOME/'error-1920.png')).check_returncode()
    (HOME/'fail-background').unlink()
    key('Return')
    assert p.wait(timeout=5) == 0
    assert state.read_text().strip() == str(images[1])
    print('PASS: failed IPC keeps UI and saved state; retry applies and exits', flush=True)

    p = start()
    data = wait(status, 'third mapping')
    assert data['selected'] == str(images[1])
    key('End')
    assert status()['selected'] == str(images[2])
    key('Return')
    assert p.wait(timeout=5) == 0
    assert state.read_text().strip() == str(images[2])
    assert not (HOME/'PWNED').exists()
    print('PASS: quoted Unicode-compatible path is data, never shell code; selected image persists', flush=True)
    tools = os.environ.get('ORGM_TEST_VIDEO_TOOLS')
    if tools:
        # The compositor/D-Bus are private, but transient units need the real
        # user manager. Forward ONLY this test's unique video-unit commands.
        import re
        for tool in ('systemd-run', 'systemctl'):
            real = shutil.which(tool)
            (bin_dir/tool).write_text('#!/usr/bin/env python3\nimport os,sys,re,json\n'
                'unit=next((a.removeprefix("--unit=") for a in sys.argv if a.startswith("--unit=")),sys.argv[-1])\n'
                'assert re.fullmatch(r"orgm-sway-video-[0-9a-f]{32}\\.service",unit),sys.argv\n'
                f'with open({str(HOME/"test-units")!r},"a") as f: f.write(unit+"\\n")\n'
                'if os.path.basename(sys.argv[0]) == "systemd-run":\n'
                ' from pathlib import Path\n'
                ' import runpy\n'
                f' module=runpy.run_path({str(ROOT/"dotfiles/config/profiles/sway/.local/bin/orgm-sway")!r})\n'
                ' players=[p.name for p in Path("/proc").iterdir() if p.name.isdecimal() and module["is_session_wallpaper_process"](p)]\n'
                ' assert not players,("old wallpaper still alive before new launch",players)\n'
                f'os.environ["DBUS_SESSION_BUS_ADDRESS"]={os.environ.get("DBUS_SESSION_BUS_ADDRESS", "unix:path=/run/user/"+str(os.getuid())+"/bus")!r}\n'
                f'os.environ["XDG_RUNTIME_DIR"]={os.environ["XDG_RUNTIME_DIR"]!r}\n'
                f'os.execv({real!r},[{real!r}]+sys.argv[1:])\n')
            (bin_dir/tool).chmod(0o755)
        env['PATH'] = str(bin_dir)+os.pathsep+tools+os.pathsep+os.environ['PATH']
        webp = profile/'D webp.webp'
        video = profile/'E video ñ ${HOME} $(touch PWNED)  #.mp4'
        command(str(Path(tools)/'ffmpeg'), '-nostdin', '-v', 'error', '-i', str(images[0]), str(webp)).check_returncode()
        command(str(Path(tools)/'ffmpeg'), '-nostdin', '-v', 'error', '-f', 'lavfi', '-i',
                'testsrc2=size=320x200:rate=10', '-t', '1', '-c:v', 'libx264', '-threads', '1', str(video)).check_returncode()
        p = start()
        wait(status, 'media catalog mapping')
        key('End')
        wait(lambda: any(i['path'] == str(video) and i['ready'] for i in status()['previews']), 'video poster decoded')
        wait(lambda: any(i['path'] == str(webp) and i['ready'] for i in status()['previews']), 'WebP decoded')
        key('Return')
        assert p.wait(timeout=5) == 0, status()
        unit = (config/'sway/wallpaper-video-unit').read_text().strip()
        command('systemctl', '--user', 'is-active', '--quiet', unit).check_returncode()
        assert state.read_text().strip() == str(video)
        assert Path((config/'sway/wallpaper-preview').read_text().strip()).is_file()
        time.sleep(1.5)  # longer than the clip: loop must keep the player alive
        command('systemctl', '--user', 'is-active', '--quiet', unit).check_returncode()
        pid = command('systemctl', '--user', 'show', '--property=MainPID', '--value', unit).stdout.strip()
        player_environment = (Path('/proc')/pid/'environ').read_bytes().split(b'\0')
        if b'__NV_PRIME_RENDER_OFFLOAD=1' in player_environment:
            import xml.etree.ElementTree as ET
            report = command('nvidia-smi', '-q', '-x')
            report.check_returncode()
            gpu_pids = {p.text for p in ET.fromstring(report.stdout).findall('.//process_info/pid')}
            assert pid in gpu_pids, ('offloaded player missing from NVIDIA process list', pid, gpu_pids)
            print('PASS: nvidia-offload player is present in NVIDIA GPU process list', flush=True)
        else:
            print('INFO: private player uses default GPU (NVIDIA unavailable or offload fallback)', flush=True)
        layers = json.loads(command(real_swaymsg, '-r', '-t', 'get_outputs').stdout)
        assert all(any(l['namespace'] == 'mpvpaper' for l in o.get('layer_shell_surfaces', [])) for o in layers), layers
        # Deliberately create an unrecorded duplicate in ONLY this compositor;
        # the next selection must collect it, not just the saved systemd unit.
        stray = subprocess.Popen([str(Path(tools)/'mpvpaper'), '-o', 'no-audio loop-file=inf', 'ALL', str(video)],
            env=env, cwd=HOME, stdout=log, stderr=log, start_new_session=True)
        children.append(stray)
        time.sleep(.4)
        assert stray.poll() is None
        other_video = HOME/'other video.mp4'
        shutil.copyfile(video, other_video)
        backend_command = str(ROOT/'dotfiles/config/profiles/sway/.local/bin/orgm-sway')
        for selection in (other_video, video, other_video, video):
            command(backend_command, 'wallpaper-set', str(selection)).check_returncode()
        assert stray.wait(timeout=3) is not None
        # Race two setters; flock + pre-launch assertions must still permit no
        # overlap, and the final compositor must have exactly one player.
        setters = [subprocess.Popen([backend_command, 'wallpaper-set', str(video)], env=env,
                   cwd=HOME, stdout=log, stderr=log, start_new_session=True) for _ in range(2)]
        children.extend(setters)
        assert all(process.wait(timeout=10) == 0 for process in setters)
        def single_player_layers():
            outputs = json.loads(command(real_swaymsg, '-r', '-t', 'get_outputs').stdout)
            # Type=exec does not imply the first Wayland surface is committed.
            return outputs if all(sum(l['namespace'] == 'mpvpaper' for l in o.get('layer_shell_surfaces', [])) == 1
                                  for o in outputs) else None
        layers = wait(single_player_layers, 'one player mapped on each output after concurrent setters')
        assert all(not any(l['namespace'] == 'wallpaper' for l in o.get('layer_shell_surfaces', [])) for o in layers), layers
        unit = (config/'sway/wallpaper-video-unit').read_text().strip()
        command(backend_command, 'wallpaper').check_returncode()
        restored = (config/'sway/wallpaper-video-unit').read_text().strip()
        assert restored != unit
        assert command('systemctl', '--user', 'is-active', '--quiet', unit).returncode != 0
        command('systemctl', '--user', 'is-active', '--quiet', restored).check_returncode()
        p = start()
        wait(status, 'saved video selection')
        assert status()['selected'] == str(video)
        key('Left')
        key('Return')
        assert p.wait(timeout=5) == 0
        assert state.read_text().strip() == str(webp)
        assert command('systemctl', '--user', 'is-active', '--quiet', restored).returncode != 0
        assert not (HOME/'PWNED').exists()
        print('PASS: WebP/video, stop-before-start, stray-player cleanup, concurrent setters, loop, restore and image switch', flush=True)
    # A missing executable must also release busy state and permit cancellation.
    backend = ROOT/'dotfiles/config/profiles/sway/.local/bin/orgm-sway'
    import runpy
    from unittest.mock import patch
    module = runpy.run_path(str(backend))
    with patch.dict(os.environ, env, clear=True), patch.object(Path, 'home', return_value=HOME):
        catalog = module['wallpaper_catalog']()
    catalog['backend'] = str(HOME/'does-not-exist')
    data_file = HOME/'missing-backend.json'
    data_file.write_text(json.dumps(catalog))
    p = subprocess.Popen([str(QS), '--path', str(config/'quickshell/orgm-wallpapers')],
        env=dict(env, ORGM_WALLPAPER_DATA=str(data_file)), cwd=HOME,
        stdout=log, stderr=log, start_new_session=True)
    children.append(p)
    wait(status, 'missing executable mapping')
    key('Return')
    data = wait(lambda: (s if (s := status()) and s['error'] and not s['busy'] else None), 'launch failure feedback')
    key('Escape')
    assert p.wait(timeout=5) == 0
    print('PASS: missing backend does not trap keyboard input', flush=True)
    catalog['items'] = []
    catalog['current'] = ''
    data_file.write_text(json.dumps(catalog))
    p = subprocess.Popen([str(QS), '--path', str(config/'quickshell/orgm-wallpapers')],
        env=dict(env, ORGM_WALLPAPER_DATA=str(data_file)), cwd=HOME,
        stdout=log, stderr=log, start_new_session=True)
    children.append(p)
    data = wait(status, 'empty catalog mapping')
    assert data['count'] == 0
    key('Return')
    assert p.poll() is None and not status()['busy']
    key('Escape')
    assert p.wait(timeout=5) == 0
    print('PASS: empty folders render and can be cancelled without applying anything', flush=True)
    data_file.write_text('not valid JSON')
    startup_status = HOME/'startup-status'
    failed = subprocess.run([str(QS), '--path', str(config/'quickshell/orgm-wallpapers')],
        env=dict(env, ORGM_WALLPAPER_DATA=str(data_file), ORGM_WALLPAPER_STATUS=str(startup_status)), cwd=HOME,
        stdout=log, stderr=log, timeout=5)
    assert startup_status.read_text() == 'error'
    print('PASS: invalid catalog reports startup failure and exits for the Rofi fallback', flush=True)
    contents = (HOME/'session.log').read_text()
    assert 'Failed to load configuration' not in contents, contents
    assert 'ReferenceError' not in contents and 'TypeError' not in contents, contents
finally:
    if (HOME/'test-units').is_file():
        for unit in set((HOME/'test-units').read_text().splitlines()):
            command('systemctl', '--user', 'stop', unit)
    # Only process groups launched above, within the private test session.
    for process in children+[sway]:
        if process.poll() is None:
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait(timeout=3)
    log.close()
    print('Private logs/previews:', HOME, flush=True)
