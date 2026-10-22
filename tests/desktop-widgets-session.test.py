#!/usr/bin/env python3
"""Real private Sway/Wayland widget rendering; never connects to the live session."""
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'tests/helpers'))
from wayland_pointer import Pointer
SOURCE = ROOT/'dotfiles/config/profiles/wayland'
SWAY = os.environ.get('ORGM_TEST_SWAY') or shutil.which('sway')
if not SWAY:
    raise SystemExit('SKIP: Sway test compositor unavailable (no build requested)')
home = Path(tempfile.mkdtemp(prefix='widgets-'))
runtime = home/'r'
runtime.mkdir(mode=0o700)
shutil.copytree(SOURCE/'.config', home/'.config')
shutil.copytree(SOURCE/'.local', home/'.local')
(home/'sway.conf').write_text('xwayland disable\noutput HEADLESS-1 mode 1280x720\nfont pango:monospace 10\n')
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
pointer = None
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


def cursor(x, y):
    pointer.move(x, y)
    time.sleep(.08)


def click(x, y):
    cursor(x, y)
    pointer.button(True)
    pointer.button(False)
    time.sleep(.12)


def drag(widget, dx, dy):
    before = next(s for s in state()['screens'] if s['widget'] == widget and s['screen'] == 'HEADLESS-1')
    x, y = before['x'] + before['width']/2, before['y'] + before['height']/2
    cursor(x, y)
    pointer.button(True)
    for step in range(1, 6):
        cursor(x + dx * step/5, y + dy * step/5)
    pointer.button(False)
    time.sleep(.15)
    return before


try:
    env['SWAYSOCK'] = str(wait(lambda: next(runtime.glob('sway-ipc.*.sock'), None), 'IPC'))
    env['WAYLAND_DISPLAY'] = wait(lambda: next((p.name for p in runtime.glob('wayland-*') if p.is_socket()), None), 'Wayland')
    env['DBUS_SESSION_BUS_ADDRESS'] = (home/'bus').read_text()
    children.append(subprocess.Popen(['wtype', '-s', '120000'], env=env, stdout=log, stderr=log))
    time.sleep(.1)
    widget = subprocess.Popen([str(home/'.local/bin/orgm-desktop-widgets'), 'daemon'],
        env=env, stdout=log, stderr=log)
    children.append(widget)
    initial = wait(lambda: (data := state()) and len(data['screens']) == 2 and data, 'two widget surfaces')
    assert initial['design'] == 'digital'
    assert initial.get('editing') is False, 'widgets need an explicit locked/editing mode'
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
    pointer = Pointer(runtime/env['WAYLAND_DISPLAY'])
    command(str(home/'.local/bin/orgm-desktop-widgets'), 'edit').check_returncode()
    wait(lambda: state()['editing'], 'edit mode')
    drag('clock', 260, 220)
    drag('calendar', 600, -330)
    path = home/'.config/orgm-desktop/widgets.json'
    def saved():
        data = json.loads(path.read_text())
        return data.get('screens', {}).get('HEADLESS-1', {})
    wait(lambda: saved().get('calendarX') == 664, 'drag persistence')
    assert saved() == dict(clockX=332, clockY=284, calendarX=664, calendarY=72), saved()
    moved = {s['widget']: s for s in state()['screens']}
    assert moved['calendar']['y'] < moved['clock']['y'], 'free placement must not force calendar below clock'
    command('grim', str(home/'editor.png')).check_returncode()
    # Both disabled widgets must remain recoverable through the editor toolbar.
    click(529, 90)
    click(751, 90)
    wait(lambda: all(not s['visible'] for s in state()['screens']), 'both widgets hidden')
    assert state()['editing'], 'toolbar must survive an empty desktop'
    click(751, 90)
    wait(lambda: any(s['widget'] == 'calendar' and s['visible'] for s in state()['screens']), 'show calendar')
    click(808, 46)  # Actual Done button.
    wait(lambda: not state()['editing'] and not state()['saving'], 'finish editor')
    before = saved().copy()
    drag('calendar', -100, 30)
    assert saved() == before, 'normal desktop must not be draggable'
    widget.terminate(); widget.wait(timeout=5)
    widget = subprocess.Popen([str(home/'.local/bin/orgm-desktop-widgets'), 'daemon'], env=env, stdout=log, stderr=log)
    children.append(widget)
    wait(lambda: (data := state()) and len(data['screens']) == 2 and not data['editing'], 'restart locked')
    restored = {s['widget']: s for s in state()['screens']}
    assert restored['clock']['visible'] is False
    assert (restored['calendar']['x'], restored['calendar']['y']) == (664, 72), restored
    command(str(home/'.local/bin/orgm-desktop-widgets'), 'edit').check_returncode()
    wait(lambda: state()['editing'], 'reopen editor')
    click(529, 90)
    command('wtype', '-k', 'Escape').check_returncode()
    wait(lambda: not state()['editing'] and not state()['saving'], 'Escape ends edit mode')
    assert all(s['visible'] for s in state()['screens'])
    # A broken file must remain untouched and show a recoverable save error.
    good = path.read_text()
    command(str(home/'.local/bin/orgm-desktop-widgets'), 'edit').check_returncode()
    wait(lambda: state()['editing'], 'edit before save error')
    path.write_text('broken JSON')
    time.sleep(.2)
    click(529, 90)
    wait(lambda: state()['error'] and not state()['saving'], 'save error is visible')
    assert path.read_text() == 'broken JSON', 'editor must not replace invalid user data with defaults'
    path.write_text(good)
    time.sleep(.2)
    click(529, 90)
    wait(lambda: not state()['error'] and not state()['saving'], 'retry recovers')
    click(529, 90)
    command(str(home/'.local/bin/orgm-desktop-widgets'), 'done').check_returncode()
    wait(lambda: not state()['editing'] and not state()['saving'], 'finish after retry')
    command('swaymsg', 'create_output').check_returncode()
    wait(lambda: len(state()['screens']) == 4, 'hotplug after saving')
    other = [s for s in state()['screens'] if s['screen'] != 'HEADLESS-1']
    assert all(s['x'] in (64, 72) for s in other), 'a new monitor must not inherit another monitor position'
    command('swaymsg', 'output '+other[0]['screen']+' disable').check_returncode()
    wait(lambda: len(state()['screens']) == 2, 'final output cleanup')
    command('grim', str(home/'saved-layout.png')).check_returncode()
    print('PASS: rendering, scaling/hotplug, actual drag/toggles/Done/Escape, locked mode and persistence after restart; artifacts:', home)
finally:
    if pointer is not None:
        pointer.close()
    for p in reversed(children):
        if p.poll() is None:
            p.terminate()
            p.wait(timeout=5)
    if compositor.poll() is None:
        os.killpg(compositor.pid, signal.SIGTERM)
        compositor.wait(timeout=5)
    log.close()
