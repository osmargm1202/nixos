#!/usr/bin/env python3
"""Explicit opt-in hardware test: real cards, captures and exact click focus.

Temporarily opens the user's switcher and changes focus, then restores it.
Never runs during a default test invocation.
"""
import json
import os
from pathlib import Path
import subprocess
import time

from helpers.wayland_pointer import Pointer

if os.environ.get('ORGM_TEST_LIVE_HYPRLAND') != '1':
    print('SKIP: hardware switcher test requires ORGM_TEST_LIVE_HYPRLAND=1')
    raise SystemExit(0)
instance = json.loads(subprocess.check_output(['hyprctl', 'instances', '-j']))[0]
env = dict(os.environ, WAYLAND_DISPLAY=instance['wl_socket'], HYPRLAND_INSTANCE_SIGNATURE=instance['instance'])
config = str(Path.home()/'.config/quickshell/orgm-wallpapers/daemon.qml')
backend = str(Path.home()/'.local/bin/orgm-hyprland-desktop')


def command(*args):
    return subprocess.check_output(args, env=env, text=True, timeout=5)


def status():
    return json.loads(command('qs', '--path', config, 'ipc', 'call', 'menu', 'status'))


original = json.loads(command('hyprctl', '-j', 'activewindow'))
cursor = json.loads(command('hyprctl', '-j', 'cursorpos'))
monitor = next(m for m in json.loads(command('hyprctl', '-j', 'monitors')) if m['focused'])
assert monitor['x'] == monitor['y'] == 0 and monitor['scale'] == 1, 'fixture requires single unscaled output at origin'
pointer = Pointer(Path(env['XDG_RUNTIME_DIR'])/env['WAYLAND_DISPLAY'])
try:
    command(backend, 'windows')
    time.sleep(.4)
    deadline = time.monotonic()+8
    while time.monotonic() < deadline:
        cards = [c for g in status()['overview']['groups'] for c in g['windows']]
        if cards and all(c['previewReady'] for c in cards):
            break
        time.sleep(.1)
    assert cards and all(c['previewReady'] for c in cards), 'native window export did not produce content'
    items = {item['id']: item for item in status()['items']}
    target = next(c for c in cards if items[c['id']]['workspace'] != original['workspace']['name']
                  and 80 < c['y']+c['height']/2 < monitor['height']-80)
    pointer.move(target['x']+target['width']/2, target['y']+target['height']/2,
                 monitor['width'], monitor['height'])
    pointer.button(True)
    pointer.button(False)
    deadline = time.monotonic()+4
    while time.monotonic() < deadline:
        active = json.loads(command('hyprctl', '-j', 'activewindow')).get('address')
        if active == target['id']:
            break
        time.sleep(.1)
    assert active == target['id'], ('selected client was not focused', active, target['id'])
    print(f'PASS: hardware session {len(cards)}/{len(cards)} native captures and exact cross-workspace click focus')
finally:
    command('qs', '--path', config, 'ipc', 'call', 'menu', 'close')
    time.sleep(.2)
    pointer.move(cursor['x'], cursor['y'], monitor['width'], monitor['height'])
    pointer.close()
    command(backend, 'windows-focus', original['address'])
