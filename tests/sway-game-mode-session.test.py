#!/usr/bin/env python3
"""Real SwayFX gaming round trip on private Wayland, HOME and D-Bus endpoints."""
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import signal
import struct
import subprocess
import tempfile
import time
import zlib

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT/'dotfiles/config/profiles/sway/.local/bin/sway-game-mode'
home = Path(tempfile.mkdtemp(prefix='sway-game-mode-session-'))
config = home/'.config/sway'
config.mkdir(parents=True)
runtime = home/'runtime'
runtime.mkdir(mode=0o700)
binary = home/'bin'
binary.mkdir()
# A private fixture must never stop the real session's dock service.
(binary/'systemctl').write_text('#!/usr/bin/env python3\nimport pathlib,sys\n'
    f'p=pathlib.Path({str(home/"dock")!r})\n'
    'a=sys.argv[2]\n'
    'if a=="is-active":sys.exit(0 if p.read_text()=="active" else 3)\n'
    'p.write_text("active" if a=="start" else "inactive")\n')
(binary/'systemctl').chmod(0o755)
(home/'dock').write_text('active')


def chunk(kind, data):
    return struct.pack('!I', len(data))+kind+data+struct.pack('!I', zlib.crc32(kind+data))


image = home/'red.png'
image.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR', struct.pack('!2I5B', 8, 8, 8, 2, 0, 0, 0))
                  +chunk(b'IDAT', zlib.compress((b'\0'+bytes([255, 0, 0])*8)*8))+chunk(b'IEND', b''))
(config/'wallpaper').write_text(str(image)+'\n')
(config/'game-mode.conf').write_text('# Gaming desactivado\n')
production = (ROOT/'dotfiles/config/profiles/sway/.config/sway/config').read_text()
reload_hooks = '\n'.join(line.replace('env PATH="$HOME/.local/bin:$PATH" sway-game-mode',
                                     shlex.quote(str(HELPER)))
                         for line in production.splitlines()
                         if line.startswith('exec_always ') and
                         ('swaymsg gaps' in line or 'sway-game-mode sync' in line))
(config/'config').write_text(f'''output HEADLESS-1 mode 800x600
output * bg {image} fill
font pango:monospace 10
default_border none
gaps inner 7
gaps outer 9
set $dock_gap 37
gaps right $dock_gap
blur enable
shadows enable
corner_radius 13
default_dim_inactive 0.07
for_window [app_id="gaming-test"] opacity 0.65
for_window [window_type="dialog"] opacity 1
for_window [app_id="^__orgm_absent_window__$"] opacity 0.9
include {config/'game-mode.conf'}
{reload_hooks}
''')
env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(home/'.config'),
           XDG_STATE_HOME=str(home/'.local/state'), XDG_DATA_HOME=str(home/'.local/share'),
           XDG_CACHE_HOME=str(home/'.cache'), XDG_RUNTIME_DIR=str(runtime),
           PATH=str(binary)+os.pathsep+os.environ['PATH'], WLR_BACKENDS='headless',
           WLR_HEADLESS_OUTPUTS='1', WLR_RENDERER='gles2', WLR_RENDERER_ALLOW_SOFTWARE='1')
for name in ('SWAYSOCK', 'WAYLAND_DISPLAY', 'WAYLAND_SOCKET', 'DISPLAY', 'DBUS_SESSION_BUS_ADDRESS'):
    env.pop(name, None)
intel = Path('/dev/dri/by-path/pci-0000:00:02.0-render')
if intel.exists():
    env['WLR_RENDER_DRM_DEVICE'] = str(intel.resolve())
log = (home/'session.log').open('w')
compositor = subprocess.Popen(['dbus-run-session', '--', shutil.which('sway'), '-c', str(config/'config')],
                              env=env, stdout=log, stderr=log, start_new_session=True)
client = None
future = None


def wait(probe, label):
    deadline = time.monotonic()+12
    while time.monotonic() < deadline:
        result = probe()
        if result:
            return result
        assert compositor.poll() is None, 'Private compositor exited; see '+str(home/'session.log')
        time.sleep(0.05)
    raise AssertionError('Timeout: '+label+'; see '+str(home/'session.log'))


def command(*arguments):
    return subprocess.check_output(arguments, env=env, stderr=subprocess.PIPE, text=True, timeout=20)


def window():
    def visit(node):
        if node.get('app_id') == 'gaming-test':
            return node
        return next((found for child in node.get('nodes', [])+node.get('floating_nodes', [])
                     if (found := visit(child))), None)
    return visit(json.loads(command('swaymsg', '-r', '-t', 'get_tree')))


def pixel(x, y):
    data = subprocess.check_output(['grim', '-t', 'ppm', '-'], env=env, stderr=subprocess.PIPE, timeout=10)
    header = re.match(rb'P6\s+(\d+)\s+(\d+)\s+255\s', data)
    assert header, 'Unexpected screenshot format'
    offset = header.end()+(y*int(header[1])+x)*3
    return tuple(data[offset:offset+3])


def spawn_client():
    return subprocess.Popen(['kitty', '--config', 'NONE', '--class', 'gaming-test',
                             '-o', 'linux_display_server=wayland', '-o', 'background=#0000ff',
                             '-o', 'background_opacity=1', '-e', 'sleep', '120'],
                            env=env, stdout=log, stderr=log)


try:
    env['SWAYSOCK'] = str(wait(lambda: next(runtime.glob('sway-ipc.*.sock'), None), 'IPC socket'))
    env['WAYLAND_DISPLAY'] = wait(lambda: next((p.name for p in runtime.glob('wayland-*')
                                              if p.is_socket()), None), 'Wayland socket')
    command(str(HELPER), 'on')
    command(str(HELPER), 'off')
    client = spawn_client()
    initial = wait(window, 'test window')['rect']
    before = wait(lambda: pixel(400, 300) if pixel(400, 300)[2] > 80 else None, 'initial opacity')
    background_before = wait(lambda: pixel(0, 0) if pixel(0, 0)[0] > 100 else None, 'initial wallpaper')
    command(str(HELPER), 'on')
    wait(lambda: window()['rect']['x'] == 0 and window()['rect']['width'] == 800, 'zero gaps')
    wait(lambda: pixel(400, 300)[2] > before[2]+20, 'opaque existing window')
    assert (home/'dock').read_text() == 'inactive'
    command('swaymsg', 'workspace 2')
    wait(lambda: pixel(0, 0) == (0, 0, 0), 'black background')
    # Simulate a dock restarted separately; reload must reconcile active gaming.
    (home/'dock').write_text('active')
    command('swaymsg', 'reload')
    wait(lambda: pixel(0, 0) == (0, 0, 0), 'gaming survives reload')
    wait(lambda: (home/'dock').read_text() == 'inactive', 'reload hides dock again')
    future = spawn_client()
    wait(lambda: pixel(400, 300)[2] > 240 and pixel(400, 300)[0] < 10,
         'new windows inherit gaming opacity')
    wait(lambda: window()['rect']['x'] == 0 and window()['rect']['width'] == 800,
         'new workspace uses full width after reload')
    future.terminate()
    future.wait(timeout=5)
    command('swaymsg', 'workspace 1')
    wait(lambda: window()['rect']['x'] == 0 and window()['rect']['width'] == 800,
         'existing workspace keeps full width after reload')
    # Let all asynchronous production reload hooks finish before checking again.
    time.sleep(0.5)
    assert window()['rect']['x'] == 0 and window()['rect']['width'] == 800
    command(str(HELPER), 'off')
    wait(lambda: window()['rect'] == initial, 'original gaps restored')
    wait(lambda: pixel(400, 300) == before, 'configured opacity restored')
    wait(lambda: pixel(0, 0) == background_before, 'original wallpaper restored')
    assert (home/'dock').read_text() == 'active'
    print('PASS: private SwayFX gaming round trip, opacity, gaps, wallpaper, reload and dock')
finally:
    if future and future.poll() is None:
        future.terminate()
        future.wait(timeout=5)
    if client and client.poll() is None:
        client.terminate()
        client.wait(timeout=5)
    if compositor.poll() is None:
        os.killpg(compositor.pid, signal.SIGTERM)
    compositor.wait(timeout=10)
    log.close()
