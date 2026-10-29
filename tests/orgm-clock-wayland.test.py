#!/usr/bin/env python3
"""Render the clock on an isolated headless Sway output, never the real desktop."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

root = Path(__file__).resolve().parents[1]
qml = root / 'dotfiles/config/hosts/orgm/shared/.config/hypr/idle-clock/shell.qml'
with tempfile.TemporaryDirectory(prefix='orgm-clock-wayland-') as temp:
    home = Path(temp); runtime = home / 'runtime'; runtime.mkdir(mode=0o700)
    (home / 'sway.conf').write_text('xwayland disable\noutput HEADLESS-1 mode 1280x720\n')
    env = dict(os.environ, HOME=temp, XDG_RUNTIME_DIR=str(runtime), WLR_BACKENDS='headless',
               WLR_HEADLESS_OUTPUTS='1', WLR_RENDERER='pixman', XDG_CURRENT_DESKTOP='sway',
               QT_QPA_PLATFORM='wayland')
    for key in ('WAYLAND_DISPLAY', 'WAYLAND_SOCKET', 'SWAYSOCK', 'DISPLAY', 'HYPRLAND_INSTANCE_SIGNATURE',
                'DBUS_SESSION_BUS_ADDRESS', 'QS_CONFIG_PATH', 'QS_CONFIG_NAME'):
        env.pop(key, None)
    log = (home / 'log').open('w+')
    compositor = subprocess.Popen(['dbus-run-session', '--', shutil.which('sway'), '-c', str(home/'sway.conf')],
                                  env=env, cwd=temp, stdout=log, stderr=log)
    clock = None
    try:
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline:
            sockets = [p for p in runtime.glob('wayland-*') if not p.name.endswith('.lock')]
            if sockets: break
            assert compositor.poll() is None, 'private compositor exited'
            time.sleep(.05)
        else: raise AssertionError('private Wayland socket did not appear')
        env['WAYLAND_DISPLAY'] = sockets[0].name
        clock = subprocess.Popen([shutil.which('qs'), '--path', str(qml)], env=env, cwd=temp, stdout=log, stderr=log)
        time.sleep(3)
        log.flush()
        assert clock.poll() is None, (home/'log').read_text()
        assert not any(x in (home/'log').read_text() for x in ('Type FlipClock unavailable', 'Failed to load configuration', 'Cannot assign to non-existent')), (home/'log').read_text()
        subprocess.run([shutil.which('grim'), str(home/'clock.png')], env=env, check=True, timeout=10)
        assert (home/'clock.png').stat().st_size > 5000
        shutil.copyfile(home/'clock.png', '/tmp/orgm-idle-clock-preview.png')
        print('PASS: idle clock renders on a private Wayland output')
    finally:
        if clock is not None and clock.poll() is None: clock.terminate(); clock.wait(timeout=5)
        compositor.terminate(); compositor.wait(timeout=5)
        log.close()
