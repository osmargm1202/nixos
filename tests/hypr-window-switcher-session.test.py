#!/usr/bin/env python3
"""Real switcher clicks and per-window capture in an isolated nested Hyprland.

Requires ORGM_TEST_PARENT_DISPLAY explicitly naming a parent Wayland socket.
Creates one nested test window; never edits the parent config or session bus.
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
parent_display = os.environ.get('ORGM_TEST_PARENT_DISPLAY')
if not parent_display or not shutil.which('Hyprland'):
    print('SKIP: nested switcher session requires ORGM_TEST_PARENT_DISPLAY and Hyprland')
    raise SystemExit(0)

with tempfile.TemporaryDirectory(prefix='hs-') as tmp:
    home = Path(tmp)
    runtime = home/'r'
    runtime.mkdir(mode=0o700)
    config = home/'.config'
    ui = config/'quickshell/orgm-wallpapers'
    shutil.copytree(ROOT/'dotfiles/config/profiles/wayland/.config/quickshell/orgm-wallpapers', ui)
    binary = home/'.local/bin'
    binary.mkdir(parents=True)
    library = binary.parent/'lib/orgm-wayland'
    shutil.copytree(ROOT/'dotfiles/config/profiles/wayland/.local/lib/orgm-wayland', library)
    shutil.copy2(ROOT/'dotfiles/config/profiles/hyprland/.local/lib/orgm-wayland/hyprland.py', library/'hyprland.py')
    for name in ('orgm-hyprland', 'orgm-hyprland-desktop'):
        shutil.copy2(ROOT/'dotfiles/config/profiles/hyprland/.local/bin'/name, binary/name)
    env = dict(os.environ, HOME=tmp, XDG_CONFIG_HOME=str(config), XDG_CACHE_HOME=str(home/'.cache'),
               XDG_STATE_HOME=str(home/'.state'), XDG_DATA_HOME=str(home/'.data'),
               XDG_RUNTIME_DIR=str(runtime), QT_QPA_PLATFORM='wayland',
               XDG_CURRENT_DESKTOP='Hyprland', PATH=str(binary)+':'+os.environ['PATH'],
               DBUS_SESSION_BUS_ADDRESS='unix:path='+str(home/'no-bus'),
               HYPRLAND_NO_SD_VARS='1', HYPRLAND_NO_SD_NOTIFY='1', HYPRLAND_NO_RT='1')
    for key in ('WAYLAND_DISPLAY', 'WAYLAND_SOCKET', 'DISPLAY', 'SWAYSOCK', 'I3SOCK',
                'HYPRLAND_INSTANCE_SIGNATURE', 'QS_CONFIG_PATH', 'QS_CONFIG_NAME'):
        env.pop(key, None)
    (home/'hyprland.lua').write_text('hl.monitor({output="",mode="1280x800@60",position="0x0",scale=1})\n'
        'hl.config({general={layout="scrolling"},animations={enabled=false},input={follow_mouse=1},debug={disable_logs=false}})\n'
        f'dofile({json.dumps(str(ROOT/"dotfiles/config/profiles/hyprland/.config/hypr/lua/layout.lua"))})\n'
        f'dofile({json.dumps(str(ROOT/"dotfiles/config/profiles/hyprland/.config/hypr/lua/window-rules.lua"))})\n'
        f'dofile({json.dumps(str(ROOT/"dotfiles/config/users/osmarg/profiles/hyprland/.config/hypr/lua/keybindings.lua"))})'
        '.setup({terminal="kitty",fileManager="nautilus"})\n')
    children = []
    log = (home/'session.log').open('w')

    def start(*args, environment=None):
        child = subprocess.Popen(args, env=environment or env, stdout=log, stderr=log, start_new_session=True)
        children.append(child)
        return child

    def command(*args):
        return subprocess.run(args, env=env, capture_output=True, text=True, timeout=8, check=True).stdout

    def wait(probe, label):
        deadline = time.monotonic()+12
        while time.monotonic() < deadline:
            value = probe()
            if value:
                return value
            time.sleep(.08)
        raise AssertionError('Timeout: '+label)

    def clients():
        return json.loads(command('hyprctl', '-j', 'clients'))

    def status():
        try:
            return json.loads(command('qs', '--path', str(ui/'daemon.qml'), 'ipc', 'call', 'menu', 'status'))
        except (subprocess.SubprocessError, json.JSONDecodeError):
            return {}

    pointer = None
    try:
        env.update(WAYLAND_DISPLAY=parent_display, AQ_DRM_DEVICES='/dev/null')
        compositor = start('Hyprland', '--config', str(home/'hyprland.lua'))
        control = wait(lambda: next(runtime.glob('hypr/*/.socket.sock'), None), 'private Hyprland')
        env['HYPRLAND_INSTANCE_SIGNATURE'] = control.parent.name
        display = wait(lambda: next((p for p in runtime.glob('wayland-*') if p.is_socket()), None), 'nested display')
        env['WAYLAND_DISPLAY'] = display.name
        wait(lambda: json.loads(command('hyprctl', '-j', 'monitors')), 'nested output')
        assert not command('hyprctl', 'configerrors').strip(), 'nested Lua config must register all bindings'
        for workspace, (name, color) in enumerate((('switcher-a', '#c00000'), ('switcher-b', '#0000c0')), 1):
            command('hyprctl', 'dispatch', f'hl.dsp.focus({{workspace={workspace}}})')
            start('kitty', '--config', 'NONE', '--class', name, '-o', 'linux_display_server=wayland',
                  '-o', 'background='+color, '-o', 'confirm_os_window_close=0', 'sh', '-c', 'sleep 120')
            wait(lambda: any(c['class'] == name for c in clients()), name)
        a = next(c['address'] for c in clients() if c['class'] == 'switcher-a')
        b = next(c['address'] for c in clients() if c['class'] == 'switcher-b')
        start('kitty', '--config', 'NONE', '--class', 'switcher-c', '-o', 'linux_display_server=wayland',
              '-o', 'confirm_os_window_close=0', 'sh', '-c', 'sleep 120')
        wait(lambda: any(c['class'] == 'switcher-c' for c in clients()), 'third column')
        command('hyprctl', 'dispatch', 'hl.dsp.focus({window="address:'+b+'"})')
        time.sleep(.3)
        column = next(c for c in clients() if c['address'] == b)
        output = json.loads(command('hyprctl', '-j', 'monitors'))[0]
        assert abs(column['at'][0]+column['size'][0]/2-output['width']/2) > output['width']*.1, \
            'scrolling must fit already-visible columns, not force the focused window to the center'
        print('PASS: scrolling keeps adjacent columns visible without forced centering', flush=True)
        # Send the actual keyboard shortcut to the private compositor. A layout
        # message alone would not catch an incorrect personal binding override.
        # Use an evdev keymap: wtype's dynamically numbered keys can select
        # another binding when Hyprland resolves against its primary keymap.
        pointer = Pointer(display)
        pointer.move(column['at'][0]+column['size'][0]/2,
                     column['at'][1]+column['size'][1]/2,
                     output['width'], output['height'])
        keyboard = Keyboard(pointer)
        command('hyprctl', 'dispatch', 'hl.dsp.focus({window="address:'+b+'"})')
        wait(lambda: json.loads(command('hyprctl', '-j', 'activewindow')).get('address') == b, 'focused resize target')
        def cycle_widths(address, label):
            command('hyprctl', 'dispatch', 'hl.dsp.focus({window="address:'+address+'"})')
            # Starting at 100% proves wrapping as well as the complete cycle.
            command('hyprctl', 'dispatch', 'hl.dsp.layout("colresize 1.0")')
            for fraction in (.333, .5, .667, 1.0, .333):
                keyboard.key(125, True)  # KEY_LEFTMETA
                keyboard.modifiers(64)  # Mod4 / SUPER
                keyboard.key(19, True)  # KEY_R
                keyboard.key(19, False)
                keyboard.modifiers(0)
                keyboard.key(125, False)
                resized = wait(lambda: next((c for c in clients() if c['address'] == address
                                    and abs(c['size'][0]/output['width']-fraction) < .04), None),
                               f'Win+R {label} column width {fraction}')
                assert not resized['fullscreen'], 'width cycling must not hide bar/dock via fullscreen'
                assert json.loads(command('hyprctl', '-j', 'activewindow')).get('address') == address
                time.sleep(.1)
            print('PASS: real Win+R cycles 100 → 33 → 50 → 66 → 100 → 33% ('+label+')', flush=True)

        cycle_widths(b, 'multiple columns')
        cycle_widths(a, 'single column')
        command('hyprctl', 'dispatch', 'hl.dsp.focus({window="address:'+b+'"})')
        command('hyprctl', 'dispatch', 'hl.dsp.layout("colresize 0.5")')
        # Leave the pointer over B: after closing the overlay it must still
        # focus the clicked card A, not restore the underlying window B.
        command('hyprctl', 'dispatch', 'hl.dsp.focus({window="address:'+b+'"})')
        start(str(binary/'orgm-hyprland-desktop'), 'menus-daemon')
        wait(lambda: status(), 'resident menu')

        def menu_ready():
            state = status()
            return state if state.get('open') and state.get('overview', {}).get('groups') else None

        command(str(binary/'orgm-hyprland-desktop'), 'windows')
        state = wait(menu_ready, 'window cards')
        time.sleep(.3)
        state = status()
        card = next(c for g in state['overview']['groups'] for c in g['windows'] if c['id'] == a)
        monitor = json.loads(command('hyprctl', '-j', 'monitors'))[0]
        pointer.move(card['x']+card['width']/2, card['y']+card['height']/2,
                     monitor['width'], monitor['height'])
        time.sleep(.1)
        pointer.button(True)
        pointer.button(False)
        wait(lambda: not status().get('visible'), 'switcher closed')
        deadline = time.monotonic()+3
        while time.monotonic() < deadline:
            active = json.loads(command('hyprctl', '-j', 'activewindow'))
            if active.get('address') == a:
                break
            time.sleep(.1)
        assert active.get('address') == a, ('click did not focus selected window', active.get('address'), a,
                                          active.get('class'), status())
        print('PASS: actual card click focuses exact window after overlay closes', flush=True)

        for app in ('org.gnome.Nautilus', 'vlc', 'org.videolan.VLC'):
            utility = start('kitty', '--config', 'NONE', '--class', app,
                            '-o', 'linux_display_server=wayland', '-o', 'confirm_os_window_close=0',
                            'sh', '-c', 'sleep 120')
            window = wait(lambda: next((c for c in clients() if c['class'] == app), None), app)
            assert window['floating'], app+' rule must float the actual mapped client'
            assert not window['fullscreen'], app+' must retain manual fullscreen controls'
            print('PASS: actual '+app+' client maps floating under native rules', flush=True)
            os.killpg(utility.pid, signal.SIGTERM)
            utility.wait(timeout=3)

        # Keep other columns mapped: a single-column workspace would otherwise
        # fill the screen even when the per-app startup rule was missing.
        for app in ('Firefox', 'chrome-chatgpt.com__-Default'):
            browser = start('kitty', '--config', 'NONE', '--class', app,
                            '-o', 'linux_display_server=wayland', '-o', 'confirm_os_window_close=0',
                            'sh', '-c', 'sleep 120')
            opened = wait(lambda: next((c for c in clients() if c['class'] == app), None), app)
            # Refocusing the neighboring column must not reset startup width.
            command('hyprctl', 'dispatch', 'hl.dsp.focus({window="address:'+a+'"})')
            assert opened['size'][0] > json.loads(command('hyprctl', '-j', 'monitors'))[0]['width']*.9, \
                app+' must open at 100% even with another column present'
            assert not opened['floating'] and not opened['fullscreen'], app
            os.killpg(browser.pid, signal.SIGTERM)
            browser.wait(timeout=3)
        print('PASS: browser and PWA map at 100% without overriding floating/fullscreen policy', flush=True)

        if not os.environ.get('ORGM_TEST_NESTED_CAPTURE'):
            print('SKIP: nested capture not requested; hardware-session export is verified separately')
        else:
            command(str(binary/'orgm-hyprland-desktop'), 'windows')
            wait(menu_ready, 'preview menu')
            def previews_ready():
                cards = [c for g in status().get('overview', {}).get('groups', []) for c in g['windows']]
                return len(cards) == 3 and all(c.get('previewReady') for c in cards)
            wait(previews_ready, 'native per-window captured content')
            print('PASS: all native window captures contain content', flush=True)
            command('grim', str(home/'switcher.png'))
            artifact = os.environ.get('ORGM_TEST_ARTIFACTS')
            if artifact:
                Path(artifact).mkdir(parents=True, exist_ok=True)
                shutil.copy2(home/'switcher.png', Path(artifact)/'switcher.png')
    except Exception:
        log.flush()
        print((home/'session.log').read_text(errors='replace')[-7000:])
        raise
    finally:
        if pointer:
            pointer.close()
        for child in reversed(children):
            if child.poll() is None:
                os.killpg(child.pid, signal.SIGTERM)
            try:
                child.wait(timeout=3)
            except subprocess.TimeoutExpired:
                os.killpg(child.pid, signal.SIGKILL)
                child.wait()
        log.close()
