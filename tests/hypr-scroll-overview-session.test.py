#!/usr/bin/env python3
"""Native plugin + real Alt+Tab in an explicitly requested private Hyprland.

No parent config, session bus, lock state or application processes are modified.
The built plugin must be supplied explicitly; this test does not build anything.
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

ROOT = Path(__file__).resolve().parents[1]
parent = os.environ.get('ORGM_TEST_PARENT_DISPLAY')
plugin = os.environ.get('ORGM_TEST_SCROLLOVERVIEW_PLUGIN')
if not parent or not plugin or not all(shutil.which(x) for x in ('Hyprland', 'hyprctl', 'kitty')):
    print('SKIP: native overview requires explicit parent display, built plugin and Hyprland/kitty')
    raise SystemExit(0)
assert Path(plugin).is_file(), 'explicit built plugin must exist'

with tempfile.TemporaryDirectory(prefix='ho-') as tmp:
    home = Path(tmp)
    runtime = home/'r'
    runtime.mkdir(mode=0o700)
    state = home/'state'
    link = state/'orgm-hyprland-tools/scrolloverview/lib/libscrolloverview.so'
    link.parent.mkdir(parents=True)
    link.symlink_to(Path(plugin).resolve())
    binary = home/'bin'
    binary.mkdir()
    fallback = home/'fallback'
    (binary/'orgm-hyprland').write_text('#!/bin/sh\nprintf "%s\\n" "$*" >>"$HOME/fallback"\n')
    (binary/'orgm-hyprland').chmod(0o755)
    env = dict(os.environ, HOME=tmp, XDG_RUNTIME_DIR=str(runtime), XDG_CONFIG_HOME=str(home/'config'),
               XDG_STATE_HOME=str(state), XDG_CACHE_HOME=str(home/'cache'), XDG_DATA_HOME=str(home/'data'),
               DBUS_SESSION_BUS_ADDRESS='unix:path='+str(home/'no-bus'), PATH=str(binary)+':'+os.environ['PATH'],
               HYPRLAND_NO_SD_VARS='1', HYPRLAND_NO_SD_NOTIFY='1', HYPRLAND_NO_RT='1')
    for key in ('WAYLAND_DISPLAY', 'WAYLAND_SOCKET', 'DISPLAY', 'SWAYSOCK', 'I3SOCK',
                'HYPRLAND_INSTANCE_SIGNATURE', 'QS_CONFIG_PATH', 'QS_CONFIG_NAME'):
        env.pop(key, None)
    base = ROOT/'dotfiles/config/profiles/hyprland/.config/hypr'
    config = home/'hyprland.lua'
    config.write_text(f'package.path={json.dumps(str(base/"?.lua"))} .. ";" .. package.path\n'
        'hl.monitor({output="",mode="1280x800@60",position="0x0",scale=1})\n'
        'hl.config({general={layout="scrolling"},animations={enabled=false},input={follow_mouse=0},debug={disable_logs=false}})\n'
        'require("lua.overview").register()\nrequire("lua.overview").register()\n'
        'if hl.plugin.scrolloverview then hl.plugin.scrolloverview.configure({layout="vertical",scale=0.5,workspace_gap=24,blur=false}) end\n'
        f'dofile({json.dumps(str(ROOT/"dotfiles/config/users/osmarg/profiles/hyprland/.config/hypr/lua/keybindings.lua"))})'
        '.setup({terminal="kitty",fileManager="nautilus"})\n')
    children = []
    log = (home/'session.log').open('w')
    pointer = None

    def start(*args):
        process = subprocess.Popen(args, env=env, stdout=log, stderr=log, start_new_session=True)
        children.append(process)
        return process

    def command(*args):
        return subprocess.run(args, env=env, capture_output=True, text=True, check=True, timeout=8).stdout

    def wait(probe, label):
        deadline = time.monotonic()+12
        while time.monotonic() < deadline:
            result = probe()
            if result:
                return result
            time.sleep(.08)
        raise AssertionError('Timeout: '+label)

    def clients():
        return json.loads(command('hyprctl', '-j', 'clients'))

    try:
        env.update(WAYLAND_DISPLAY=parent, AQ_DRM_DEVICES='/dev/null')
        compositor = start('Hyprland', '--config', str(config))
        control = wait(lambda: next(runtime.glob('hypr/*/.socket.sock'), None), 'private IPC')
        env['HYPRLAND_INSTANCE_SIGNATURE'] = control.parent.name
        display = wait(lambda: next((p for p in runtime.glob('wayland-*') if p.is_socket()), None), 'private display')
        env['WAYLAND_DISPLAY'] = display.name
        wait(lambda: json.loads(command('hyprctl', '-j', 'monitors')), 'private output')
        def loaded():
            return 'scrolloverview' in command('hyprctl', 'plugin', 'list').lower()
        wait(loaded, 'declarative plugin registration and exact runtime ABI')
        assert not command('hyprctl', 'configerrors').strip()
        # Registered only once even with two module calls and multiple reloads.
        for _ in range(2):
            command('hyprctl', 'reload')
            wait(loaded, 'plugin retained after reload')
            assert not command('hyprctl', 'configerrors').strip()
        listing = command('hyprctl', 'plugin', 'list')
        assert listing.lower().count('plugin scrolloverview') == 1, listing
        print('PASS: native plugin ABI, declarative startup and repeated reload', flush=True)
        for workspace in (1, 2):
            command('hyprctl', 'dispatch', f'hl.dsp.focus({{workspace={workspace}}})')
            start('kitty', '--config', 'NONE', '--class', 'overview-'+str(workspace),
                  '-o', 'linux_display_server=wayland', '-o', 'confirm_os_window_close=0', 'sh', '-c', 'sleep 90')
            wait(lambda: any(c['class'] == 'overview-'+str(workspace) for c in clients()), 'test client')
        target = next(c['address'] for c in clients() if c['class'] == 'overview-1')
        other = next(c['address'] for c in clients() if c['class'] == 'overview-2')
        pointer = Pointer(display)
        keyboard = Keyboard(pointer)
        def press(code):
            keyboard.key(code, True)
            keyboard.key(code, False)
        def shortcut(shift=False):
            keyboard.key(56, True)  # ALT
            if shift:
                keyboard.key(42, True)
            keyboard.modifiers(8 | (1 if shift else 0))
            press(15)  # TAB
            keyboard.modifiers(0)
            if shift:
                keyboard.key(42, False)
            keyboard.key(56, False)
        for shift in (False, True):
            command('hyprctl', 'dispatch', 'hl.dsp.focus({window="address:'+other+'"})')
            shortcut(shift)
            time.sleep(.15)
            assert not fallback.exists(), 'plugin opening must not fall back silently'
            press(103)  # UP selects the previous workspace in vertical overview.
            press(28)  # ENTER accepts the selected window.
            wait(lambda: json.loads(command('hyprctl', '-j', 'activewindow')).get('address') == target,
                 'real Alt+Tab / Up / Enter changes workspace and window')
            print('PASS: native '+('Shift+' if shift else '')+'Alt+Tab opens interactive overview and selects another window', flush=True)
            time.sleep(.2)
        assert not command('hyprctl', 'configerrors').strip()
        assert compositor.poll() is None and not fallback.exists()
    except Exception:
        log.flush()
        print((home/'session.log').read_text(errors='replace')[-8000:])
        raise
    finally:
        if pointer:
            pointer.close()
        for process in reversed(children):
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGTERM)
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
        log.close()
