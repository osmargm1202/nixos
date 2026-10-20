#!/usr/bin/env python3
"""Real dock clicks must focus exact clients across workspaces.

Opt-in: requires an unlocked parent compositor delivering frames to the nested
window. A locked/occluded parent can withhold frame callbacks after the first
click, so GTK cannot allocate its rebuilt buttons; that is not an IPC failure.
"""
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile
import time

from helpers.wayland_pointer import Pointer
from helpers.wayland_keyboard import Keyboard

parent = os.environ.get('ORGM_TEST_PARENT_DISPLAY')
if not parent or not shutil.which('Hyprland'):
    print('SKIP: requires ORGM_TEST_PARENT_DISPLAY and Hyprland')
    raise SystemExit(0)
dock = os.environ.get('ORGM_TEST_DOCK', 'nwg-dock-hyprland')

# Hyprland's signature is long; keep the Unix-domain socket path below 108 bytes.
with tempfile.TemporaryDirectory(prefix='dc-') as tmp:
    home = Path(tmp)
    runtime = home/'r'
    runtime.mkdir(mode=0o700)
    env = dict(os.environ, HOME=tmp, XDG_RUNTIME_DIR=str(runtime),
               XDG_CONFIG_HOME=str(home/'.config'), WAYLAND_DISPLAY=parent,
               XDG_STATE_HOME=str(home/'.state'), XDG_CACHE_HOME=str(home/'.cache'),
               XDG_DATA_HOME=str(home/'.data'), GDK_BACKEND='wayland',
               AQ_DRM_DEVICES='/dev/null', HYPRLAND_NO_SD_VARS='1',
               HYPRLAND_NO_SD_NOTIFY='1', HYPRLAND_NO_RT='1',
               DBUS_SESSION_BUS_ADDRESS='unix:path='+str(home/'no-bus'))
    for key in ('WAYLAND_SOCKET', 'DISPLAY', 'SWAYSOCK', 'HYPRLAND_INSTANCE_SIGNATURE'):
        env.pop(key, None)
    (home/'hyprland.lua').write_text(
        'hl.monitor({output="",mode="1280x800@60",position="0x0",scale=1})\n'
        'hl.config({animations={enabled=false},debug={disable_logs=false}})\n')
    log = (home/'session.log').open('w')
    children = []
    pointer = None

    def start(*args, environment=None):
        child = subprocess.Popen(args, env=environment or env, stdout=log, stderr=log, start_new_session=True)
        children.append(child)
        return child

    def wait(probe, label):
        deadline = time.monotonic()+10
        while time.monotonic() < deadline:
            result = probe()
            if result:
                return result
            time.sleep(.05)
        raise AssertionError('Timeout: '+label+'\n'+(home/'session.log').read_text()[-6000:])

    def query(name):
        return json.loads(subprocess.check_output(['hyprctl', '-j', name], env=env, text=True, timeout=8))

    try:
        compositor = start('Hyprland', '--config', str(home/'hyprland.lua'))
        socket = wait(lambda: next(runtime.glob('hypr/*/.socket.sock'), None), 'private IPC')
        env['HYPRLAND_INSTANCE_SIGNATURE'] = socket.parent.name
        display = wait(lambda: next((p for p in runtime.glob('wayland-*') if p.is_socket()), None), 'display')
        env['WAYLAND_DISPLAY'] = display.name
        wait(lambda: query('monitors'), 'output')
        pointer = Pointer(display)
        apps = home/'.data/applications'
        apps.mkdir(parents=True)
        cache = home/'.cache'
        cache.mkdir()
        (cache/'nwg-dock-pinned').write_text('orgm-dock-a\norgm-dock-b\n')
        cfg = home/'.config/nwg-dock-hyprland'
        cfg.mkdir(parents=True)
        (cfg/'style.css').write_text(
            '* { padding: 0; margin: 0; border: 0; box-shadow: none; }\n'
            'window { background: #222; }\n'
            'button { min-height: 40px; min-width: 40px; }\n')
        addresses = {}

        def dispatch(code):
            reply = subprocess.check_output(['hyprctl', 'dispatch', code], env=env, text=True, timeout=8)
            assert reply.strip() == 'ok', reply

        for workspace, cls in enumerate(('orgm-dock-a', 'orgm-dock-b'), 1):
            (apps/(cls+'.desktop')).write_text(
                '[Desktop Entry]\nType=Application\nName='+cls+'\n'
                'Icon=utilities-terminal\nStartupWMClass='+cls+'\nExec=false\n')
            dispatch(f'hl.dsp.focus({{workspace={workspace}}})')
            start('kitty', '--config', 'NONE', '--class', cls, '--title', cls,
                  '-o', 'linux_display_server=wayland', '-o', 'confirm_os_window_close=0',
                  'sh', '-c', 'sleep 90')
            client = wait(lambda: next((c for c in query('clients') if c['class'] == cls), None), cls)
            addresses[workspace] = client['address']
        bar = start('dbus-run-session', '--', dock, '-m', '-debug', '-nolauncher', '-i', '32',
                    '-p', 'right', '-a', 'center',
                    environment=dict(env, WAYLAND_DEBUG='client') if os.environ.get('ORGM_TEST_DOCK_DEBUG') else env)

        def layer():
            return next((item for monitor in query('layers').values()
                         for group in monitor['levels'].values()
                         for item in group if item['namespace'] == 'nwg-dock'), None)

        wait(layer, 'dock layout')
        time.sleep(.4)  # allow GTK's initial allocation before injecting pointer events
        def click_icon(index, count):
            geometry = layer()
            output = query('monitors')[0]
            # Leave/re-enter after GTK rebuilds its buttons on focus changes.
            pointer.move(output['width']/2, output['height']/2, output['width'], output['height'])
            time.sleep(.1)
            pointer.move(geometry['x']+geometry['w']/2,
                         geometry['y']+(index-.5)*geometry['h']/count,
                         output['width'], output['height'])
            time.sleep(.1)
            pointer.button(True)
            pointer.button(False)

        for target in (1, 2, 1):
            click_icon(target, 2)
            wait(lambda: query('activewindow').get('address') == addresses[target],
                 f'exact window on workspace {target} after dock click')
            assert query('activeworkspace')['id'] == target
            print('PASS: dock icon selects workspace', target, flush=True)
            time.sleep(.25)  # dock rebuilds its GTK buttons asynchronously after focus
        print('PASS: real dock clicks focus exact windows on workspaces 1, 2, 1', flush=True)
        # Multiple windows of one app use a separate upstream activation handler.
        dispatch('hl.dsp.focus({workspace=3})')
        start('kitty', '--config', 'NONE', '--class', 'orgm-dock-a', '--title', 'a-second',
              '-o', 'linux_display_server=wayland', 'sh', '-c', 'sleep 90')
        wait(lambda: len([c for c in query('clients') if c['class'] == 'orgm-dock-a']) == 2,
             'second app instance')
        time.sleep(.4)
        click_icon(1, 2)
        keyboard = Keyboard(pointer)
        for key in (102, 28):  # HOME selects first menu item; ENTER activates it.
            keyboard.key(key, True)
            keyboard.key(key, False)
        wait(lambda: query('activewindow').get('address') == addresses[1], 'multi-window menu focus')
        print('PASS: multi-window dock menu focuses the selected exact client', flush=True)
    except Exception:
        if os.environ.get('ORGM_TEST_ARTIFACTS'):
            artifact = Path(os.environ['ORGM_TEST_ARTIFACTS'])
            artifact.mkdir(parents=True, exist_ok=True)
            shutil.copy2(home/'session.log', artifact/'dock-session.log')
        raise
    finally:
        if pointer:
            pointer.close()
        for child in reversed(children):
            if child.poll() is None:
                os.killpg(child.pid, signal.SIGTERM)
        for child in reversed(children):
            try:
                child.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(child.pid, signal.SIGKILL)
                child.wait()
        log.close()
