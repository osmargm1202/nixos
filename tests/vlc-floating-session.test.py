#!/usr/bin/env python3
"""Map native clients with VLC identities against the real Sway rules."""
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
sway = os.environ.get('ORGM_TEST_SWAY') or shutil.which('sway')
if not sway or not shutil.which('kitty'):
    print('SKIP: VLC floating session requires SwayFX and Kitty')
    raise SystemExit(0)
swaymsg = os.environ.get('ORGM_TEST_SWAYMSG') or shutil.which('swaymsg') or str(Path(sway).parent/'swaymsg')
assert Path(swaymsg).is_file(), 'SwayFX package must provide swaymsg (or set ORGM_TEST_SWAYMSG)'

with tempfile.TemporaryDirectory(prefix='vf-') as tmp:
    home = Path(tmp)
    runtime = home/'r'
    runtime.mkdir(mode=0o700)
    env = dict(os.environ, HOME=tmp, XDG_RUNTIME_DIR=str(runtime),
               XDG_CONFIG_HOME=str(home/'.config'), WLR_BACKENDS='headless',
               WLR_HEADLESS_OUTPUTS='1', WLR_RENDERER='gles2', WLR_RENDERER_ALLOW_SOFTWARE='1',
               DBUS_SESSION_BUS_ADDRESS='unix:path='+str(home/'no-bus'))
    for key in ('WAYLAND_DISPLAY', 'WAYLAND_SOCKET', 'DISPLAY', 'SWAYSOCK', 'I3SOCK',
                'HYPRLAND_INSTANCE_SIGNATURE'):
        env.pop(key, None)
    (home/'sway.conf').write_text('output HEADLESS-1 mode 1280x800\n'
        f'include {ROOT}/dotfiles/config/profiles/sway/.config/sway/window-rules.conf\n')
    children = []
    log = (home/'session.log').open('w')

    def start(*args):
        child = subprocess.Popen(args, env=env, stdout=log, stderr=log, start_new_session=True)
        children.append(child)
        return child

    def wait(probe, label):
        deadline = time.monotonic()+12
        while time.monotonic() < deadline:
            result = probe()
            if result:
                return result
            assert compositor.poll() is None, (home/'session.log').read_text()
            time.sleep(.05)
        raise AssertionError('Timeout: '+label+'\n'+(home/'session.log').read_text()[-2000:])

    def find(node, app, floating=False):
        if node.get('app_id') == app:
            return node, floating
        for key in ('nodes', 'floating_nodes'):
            for child in node.get(key, []):
                found = find(child, app, floating or key == 'floating_nodes')
                if found:
                    return found

    def client(app):
        tree = json.loads(subprocess.check_output([swaymsg, '-r', '-t', 'get_tree'],
                                                 env=env, text=True, timeout=5))
        return find(tree, app)

    try:
        compositor = start(sway, '-c', str(home/'sway.conf'))
        ipc = wait(lambda: next(runtime.glob('sway-ipc.*.sock'), None), 'private Sway IPC')
        display = wait(lambda: next((p for p in runtime.glob('wayland-*') if p.is_socket()), None), 'private display')
        env.update(SWAYSOCK=str(ipc), WAYLAND_DISPLAY=display.name)
        for app in ('vlc', 'Vlc', 'org.videolan.VLC', 'firefox'):
            process = start('kitty', '--config', 'NONE', '--class', app, '--title', 'VLC',
                            '-o', 'linux_display_server=wayland', '-o', 'confirm_os_window_close=0',
                            'sh', '-c', 'sleep 60')
            node, floating = wait(lambda: client(app), app)
            assert floating == (app != 'firefox'), (app, floating)
            assert not node.get('fullscreen_mode'), (app, 'must retain manual fullscreen')
            os.killpg(process.pid, signal.SIGTERM)
            process.wait(timeout=5)
        print('PASS: native VLC identities float; browser titled VLC stays tiled; fullscreen remains manual')
    finally:
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
