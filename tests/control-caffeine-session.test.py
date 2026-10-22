#!/usr/bin/env python3
"""Real Waybar idle inhibitor and QS toggle in a private Sway/HOME/socket.

Only the systemctl boundary is private: it restarts this fixture's Waybar PID,
never the live user service manager. No builds, user settings or PAM involved.
"""
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time

sys.path.insert(0, str(Path(__file__).parent/'helpers'))
from wayland_pointer import Pointer

ROOT = Path(__file__).resolve().parents[1]
home = Path(tempfile.mkdtemp(prefix='control-caffeine-session-'))
runtime = home/'runtime'
runtime.mkdir(mode=0o700)
config = home/'.config'
binary = home/'.local/bin'
binary.mkdir(parents=True)
shared = ROOT/'dotfiles/config/profiles/wayland'
sway = ROOT/'dotfiles/config/profiles/sway'
shutil.copytree(shared/'.local/lib', binary.parent/'lib')
shutil.copytree(shared/'.config/quickshell/orgm-wallpapers', config/'quickshell/orgm-wallpapers')
for name in ('orgm-sway', 'orgm-sway-desktop', 'orgm-sway-waybar'):
    shutil.copy2(sway/'.local/bin'/name, binary/name)
shutil.copy2(shared/'.local/bin/waybar-caffeine-state', binary/'waybar-caffeine-state')
barconfig = config/'waybar'
barconfig.mkdir()
(barconfig/'config').write_text(json.dumps([{'layer': 'top', 'position': position, 'height': 30,
    'modules-left': ['idle_inhibitor'], 'idle_inhibitor': {'format': '{status}'}} for position in ('top','bottom')]))
(barconfig/'style.css').write_text('window#waybar { background: #111111; color: white; }')
(home/'sway.conf').write_text('xwayland disable\noutput HEADLESS-1 mode 1280x900\nfont pango:monospace 10\n')
(binary/'systemctl').write_text('#!'+sys.executable+'\n'+'''
import os,signal,subprocess,sys,time
from pathlib import Path
home=Path.home()
pidfile=home/'bar.pid'
assert sys.argv[-1]=='orgm-sway-waybar.service', sys.argv
def active():
    try:os.kill(int(pidfile.read_text()),0);return True
    except (OSError,ValueError):return False
if sys.argv[1:4]==['--user','is-active','--quiet']:sys.exit(0 if active() else 3)
assert sys.argv[1:3]==['--user','restart'],sys.argv
if active():
    os.kill(int(pidfile.read_text()),signal.SIGTERM)
    time.sleep(.2)
with (home/'bar.log').open('a') as log:
    bar=subprocess.Popen([str(home/'.local/bin/orgm-sway-waybar')],stdout=log,stderr=log,start_new_session=True)
pidfile.write_text(str(bar.pid))
''')
for name, body in {'brightnessctl': 'echo fixture,backlight,50,50%,100', 'swaync-client': 'echo false',
                   'notify-send': 'exit 0'}.items():
    (binary/name).write_text('#!/bin/sh\n'+body+'\n')
for path in binary.iterdir():
    path.chmod(0o755)
env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(config), XDG_STATE_HOME=str(home/'.local/state'),
           XDG_CACHE_HOME=str(home/'.cache'), XDG_RUNTIME_DIR=str(runtime), PATH=str(binary)+os.pathsep+os.environ['PATH'],
           XDG_CURRENT_DESKTOP='sway', QT_QPA_PLATFORM='wayland', WLR_BACKENDS='headless', WLR_HEADLESS_OUTPUTS='1',
           WLR_RENDERER='gles2', WLR_RENDERER_ALLOW_SOFTWARE='1')
for key in ('DISPLAY','SWAYSOCK','WAYLAND_DISPLAY','WAYLAND_SOCKET','DBUS_SESSION_BUS_ADDRESS','HYPRLAND_INSTANCE_SIGNATURE'):
    env.pop(key, None)
intel=Path('/dev/dri/by-path/pci-0000:00:02.0-render')
if intel.exists():env['WLR_RENDER_DRM_DEVICE']=str(intel.resolve())
log=(home/'session.log').open('w')
compositor=subprocess.Popen(['dbus-run-session','--','sh','-c',
    'printf "%s" "$DBUS_SESSION_BUS_ADDRESS" > "$1"; shift; exec "$@"','_',str(home/'bus'),
    shutil.which('sway'),'-c',str(home/'sway.conf')],env=env,stdout=log,stderr=log,start_new_session=True)
children=[]
pointer=None

def run(*args, **kwargs):
    return subprocess.run(args,env=env,capture_output=True,text=True,timeout=12,**kwargs)

def wait(probe,label):
    deadline=time.monotonic()+12
    while time.monotonic()<deadline:
        result=probe()
        if result:return result
        assert compositor.poll() is None, 'Private compositor exited; '+str(home/'session.log')
        time.sleep(.06)
    raise AssertionError('Timeout '+label+'; artifacts: '+str(home))

def start(*args):
    child=subprocess.Popen(args,env=env,stdout=log,stderr=log,start_new_session=True)
    children.append(child)
    return child

def caffeine():
    return json.loads(run(str(binary/'orgm-sway-desktop'),'control-state').stdout)['caffeine']


def center_status():
    result=run('qs','--path',str(config/'quickshell/orgm-wallpapers/menus.qml'),'ipc','call','menu','status')
    try:return json.loads(result.stdout)
    except (ValueError,KeyError):return {}

def center_state():
    return center_status().get('state', {})


def click(x,y):
    pointer.move(x,y,1280,900)
    pointer.button(True)
    pointer.button(False)

try:
    env['SWAYSOCK']=str(wait(lambda:next(runtime.glob('sway-ipc.*.sock'),None),'IPC'))
    env['WAYLAND_DISPLAY']=wait(lambda:next((p.name for p in runtime.glob('wayland-*') if p.is_socket()),None),'Wayland')
    env['DBUS_SESSION_BUS_ADDRESS']=wait(lambda:(home/'bus').read_text() if (home/'bus').exists() else '', 'D-Bus')
    pointer=Pointer(runtime/env['WAYLAND_DISPLAY'])
    # Establish the seat keyboard before any exclusive overlay appears. A
    # brand-new virtual keyboard after mapping does not receive its first key.
    start('wtype','-s','120000')
    run('systemctl','--user','restart','orgm-sway-waybar.service').check_returncode()
    wait(lambda:'waybar' in run('swaymsg','-t','get_outputs').stdout,'Waybar mapped')
    assert caffeine() is False
    idle=start('swayidle','-w','timeout','2','touch '+str(home/'idle-fired'))
    pointer.move(900,500,1280,900)
    wait(lambda:(home/'idle-fired').exists(),'uninhibited idle timeout')
    # Click native Waybar: it changes the real inhibitor and the callback writes
    # its corresponding state, which the control center must reflect.
    click(35,15)
    wait(caffeine,'native bar click persisted')
    (home/'idle-fired').unlink()
    pointer.move(910,510,1280,900)
    time.sleep(3)
    assert not (home/'idle-fired').exists(), 'Caffeine must block the real swayidle timeout'
    assert idle.poll() is None, 'Caffeine must not stop the lock/idle daemon'
    # A second bar means two real native inhibitors. Clicking either module
    # must synchronize them both, not leave another bar keeping idle blocked.
    click(35,15)
    wait(lambda:not caffeine(),'native first bar off')
    pointer.move(920,520,1280,900)
    wait(lambda:(home/'idle-fired').exists(),'both native inhibitors released')
    click(35,885)
    wait(caffeine,'native second bar on')
    (home/'idle-fired').unlink()
    pointer.move(930,530,1280,900)
    time.sleep(3)
    assert not (home/'idle-fired').exists(), 'Second bar native inhibitor must prevent idle too'
    # The actual center button applies the reverse transition through the
    # private service boundary and restores normal idle behavior.
    panel=start(str(binary/'orgm-sway-desktop'),'control')
    wait(lambda:'orgm-control' in run('swaymsg','-t','get_outputs').stdout,'center mapped')
    time.sleep(.4)
    run('grim',str(home/'caffeine-on.png')).check_returncode()
    # The complete center scrolls; find the real Caffeine control rather than
    # clicking coordinates belonging to the previous compact center.
    for _ in range(40):
        button=next(b for b in center_status()['controls'] if b['id']=='caffeine')
        if 55 < button['y'] and button['y']+button['height'] < 845:
            break
        pointer.move(640,450,1280,900)
        pointer.scroll(60 if button['y']>450 else -60)
        time.sleep(.12)
    else:
        raise AssertionError('Caffeine button never became visible')
    time.sleep(.5)  # Let Qt's wheel-scroll animation settle before aiming.
    button=next(b for b in center_status()['controls'] if b['id']=='caffeine')
    print('Caffeine target:', button, flush=True)
    run('grim',str(home/'caffeine-target.png')).check_returncode()
    assert button['enabled'], 'Caffeine must be available'
    click(button['x']+button['width']/2,button['y']+button['height']/2)
    wait(lambda:center_state().get('caffeine') is False,'center caffeine off after restart completed')
    assert panel.poll() is None, 'Caffeine toggles in place without closing the center'
    run('wtype','-k','Escape').check_returncode()
    panel.wait(timeout=5)
    pointer.move(930,530,1280,900)
    wait(lambda:(home/'idle-fired').exists(),'idle timeout restored')
    assert idle.poll() is None
    print('PASS: real native Waybar click and QS center share persisted caffeine; swayidle stays alive and inhibition is effective')
    print('Private artifacts:',home)
finally:
    if pointer:pointer.close()
    try:os.kill(int((home/'bar.pid').read_text()),signal.SIGTERM)
    except (OSError,ValueError):pass
    for child in reversed(children):
        if child.poll() is None:os.killpg(child.pid,signal.SIGTERM)
        try:child.wait(timeout=5)
        except subprocess.TimeoutExpired:os.killpg(child.pid,signal.SIGKILL)
    if compositor.poll() is None:os.killpg(compositor.pid,signal.SIGTERM)
    compositor.wait(timeout=5)
    log.close()
