#!/usr/bin/env python3
"""Click the real workspace buttons in a private nested Hyprland session."""
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile
import time

from helpers.wayland_pointer import Pointer

ROOT = Path(__file__).resolve().parents[1]
parent = os.environ.get('ORGM_TEST_PARENT_DISPLAY')
if not parent or not shutil.which('Hyprland'):
    print('SKIP: requires ORGM_TEST_PARENT_DISPLAY and Hyprland')
    raise SystemExit(0)
waybar = os.environ.get('ORGM_TEST_WAYBAR', 'waybar')

# Hyprland's signature is long; keep the Unix-domain socket path below 108 bytes.
with tempfile.TemporaryDirectory(prefix='wb-') as tmp:
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

    def start(*args):
        child = subprocess.Popen(args, env=env, stdout=log, stderr=log, start_new_session=True)
        children.append(child)
        return child

    def wait(probe, label):
        deadline = time.monotonic()+10
        while time.monotonic() < deadline:
            result = probe()
            if result:
                return result
            time.sleep(.05)
        raise AssertionError('Timeout: '+label+'\n'+(home/'session.log').read_text()[-2000:])

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
        for profile in (ROOT/'dotfiles/config/profiles/hyprland',
                        ROOT/'dotfiles/config/users/osmarg/profiles/hyprland'):
            # Use the actual workspace configuration; isolate unrelated modules.
            source = json.loads((profile/'.config/waybar-hypr/config').read_text())
            reply = subprocess.check_output(['hyprctl', 'dispatch', 'hl.dsp.focus({workspace=1})'], env=env, text=True, timeout=8)
            assert reply.strip() == 'ok', reply
            wait(lambda: query('activeworkspace')['id'] == 1, 'initial workspace')
            config = {key: source[key] for key in ('hyprland/workspaces',)}
            config.update(layer='top', position='top', height=40,
                          **{'modules-left':['hyprland/workspaces']})
            (home/'bar.json').write_text(json.dumps(config))
            (home/'bar.css').write_text(
                '* { font-family: sans-serif; font-size: 14px; }\n'
                'window#waybar { margin: 0; padding: 0; }\n'
                '#workspaces button { min-width: 60px; padding: 0; margin: 0; border: 0; }\n')
            log_start = len((home/'session.log').read_text())
            bar = start('dbus-run-session', '--', waybar, '-c', str(home/'bar.json'), '-s', str(home/'bar.css'))
            wait(lambda: 'Bar configured' in (home/'session.log').read_text()[log_start:], 'bar layout')
            time.sleep(.3)
            output = query('monitors')[0]
            for target in (2, 3, 1):
                pointer.move((target-.5)*60, 20, output['width'], output['height'])
                pointer.button(True)
                pointer.button(False)
                wait(lambda: query('activeworkspace')['id'] == target, f'workspace {target} after real Waybar click')
            os.killpg(bar.pid, signal.SIGTERM)
            bar.wait(timeout=5)
            print(f'PASS: real Waybar clicks select workspaces 2, 3, 1 ({profile})', flush=True)
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
