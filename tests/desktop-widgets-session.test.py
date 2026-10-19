#!/usr/bin/env python3
"""Real private Sway/Wayland widget rendering; never connects to the live session."""
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT/'dotfiles/config/profiles/wayland'
SWAY = os.environ.get('ORGM_TEST_SWAY') or shutil.which('sway')
if not SWAY:
    raise SystemExit('SKIP: Sway test compositor unavailable (no build requested)')
home = Path(tempfile.mkdtemp(prefix='widgets-'))
runtime = home/'r'
runtime.mkdir(mode=0o700)
shutil.copytree(SOURCE/'.config', home/'.config')
shutil.copytree(SOURCE/'.local', home/'.local')
(home/'sway.conf').write_text('output HEADLESS-1 mode 1280x720\nfont pango:monospace 10\n')
env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(home/'.config'),
           XDG_CACHE_HOME=str(home/'.cache'), XDG_DATA_HOME=str(home/'.local/share'),
           XDG_STATE_HOME=str(home/'.local/state'), XDG_RUNTIME_DIR=str(runtime),
           QT_QPA_PLATFORM='wayland', WLR_BACKENDS='headless', WLR_HEADLESS_OUTPUTS='1',
           WLR_RENDERER='gles2', WLR_RENDERER_ALLOW_SOFTWARE='1')
for key in ('DISPLAY', 'WAYLAND_DISPLAY', 'WAYLAND_SOCKET', 'SWAYSOCK', 'I3SOCK',
            'HYPRLAND_INSTANCE_SIGNATURE', 'DBUS_SESSION_BUS_ADDRESS', 'QS_CONFIG_NAME', 'QS_CONFIG_PATH'):
    env.pop(key, None)
intel = Path('/dev/dri/by-path/pci-0000:00:02.0-render')
if intel.exists():
    env['WLR_RENDER_DRM_DEVICE'] = str(intel.resolve())
log = (home/'session.log').open('w')
compositor = subprocess.Popen(['dbus-run-session', '--', 'sh', '-c',
    'printf "%s" "$DBUS_SESSION_BUS_ADDRESS" > "$1"; shift; exec "$@"', '_', str(home/'bus'), SWAY,
    '-c', str(home/'sway.conf')], env=env, stdout=log, stderr=log, start_new_session=True)
children = []
entry = home/'.config/quickshell/orgm-desktop'


def command(*args):
    return subprocess.run(args, env=env, capture_output=True, text=True, timeout=8)


def wait(probe, label):
    deadline = time.monotonic()+12
    while time.monotonic() < deadline:
        found = probe()
        if found:
            return found
        assert compositor.poll() is None, 'private compositor exited: '+str(home/'session.log')
        time.sleep(.05)
    raise AssertionError(label+': '+str(home/'session.log'))


def state():
    result = command('qs', '--path', str(entry), 'ipc', 'call', 'widgets', 'status')
    try:
        return json.loads(result.stdout) if result.returncode == 0 else None
    except ValueError:
        return None


try:
    env['SWAYSOCK'] = str(wait(lambda: next(runtime.glob('sway-ipc.*.sock'), None), 'IPC'))
    env['WAYLAND_DISPLAY'] = wait(lambda: next((p.name for p in runtime.glob('wayland-*') if p.is_socket()), None), 'Wayland')
    env['DBUS_SESSION_BUS_ADDRESS'] = (home/'bus').read_text()
    widget = subprocess.Popen([str(home/'.local/bin/orgm-desktop-widgets'), 'daemon'],
        env=env, stdout=log, stderr=log)
    children.append(widget)
    initial = wait(lambda: (data := state()) and len(data['screens']) == 2 and data, 'two widget surfaces')
    assert initial['design'] == 'digital'
    for s in initial['screens']:
        assert 0 <= s['x'] and s['x']+s['width'] <= 1280
        assert 0 <= s['y'] and s['y']+s['height'] <= 720
    # Month navigation exercises the actual calendar component, not just its model.
    command('qs', '--path', str(entry), 'ipc', 'call', 'widgets', 'shiftMonth', '1').check_returncode()
    command('qs', '--path', str(entry), 'ipc', 'call', 'widgets', 'shiftMonth', '0').check_returncode()
    # Hotplug, scaling and a small logical screen keep the widget inside its output.
    command('swaymsg', 'create_output').check_returncode()
    command('swaymsg', 'output HEADLESS-2 mode 1280x960 scale 2 pos 1280 0').check_returncode()
    wait(lambda: (data := state()) and len(data['screens']) == 4, 'hotplug widgets')
    for s in state()['screens']:
        if s['screen'] == 'HEADLESS-2':
            assert s['x']+s['width'] <= 640 and s['y']+s['height'] <= 480, s
    small = [s for s in state()['screens'] if s['screen'] == 'HEADLESS-2']
    clock = next(s for s in small if s['widget'] == 'clock')
    calendar = next(s for s in small if s['widget'] == 'calendar')
    assert clock['y']+clock['height'] <= calendar['y'] or calendar['y']+calendar['height'] <= clock['y'] \
        or clock['x']+clock['width'] <= calendar['x'] or calendar['x']+calendar['width'] <= clock['x'], small
    # A second launcher exits instead of producing duplicate widgets.
    result = command(str(home/'.local/bin/orgm-desktop-widgets'), 'daemon')
    assert result.returncode == 0 and len(state()['screens']) == 4
    if shutil.which('grim'):
        command('grim', str(home/'widgets.png')).check_returncode()
    command('swaymsg', 'output HEADLESS-2 disable').check_returncode()
    wait(lambda: len(state()['screens']) == 2, 'output cleanup')
    print('PASS: rendered widgets, bounded layout, scaling/hotplug, month navigation and singleton; artifacts:', home)
finally:
    for p in reversed(children):
        if p.poll() is None:
            p.terminate()
            p.wait(timeout=5)
    if compositor.poll() is None:
        os.killpg(compositor.pid, signal.SIGTERM)
        compositor.wait(timeout=5)
    log.close()
