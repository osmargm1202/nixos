#!/usr/bin/env python3
"""Origin must share session data while dock clicks select exact webapps.

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
import http.server
import threading

from helpers.wayland_pointer import Pointer

parent = os.environ.get('ORGM_TEST_PARENT_DISPLAY')
browser = os.environ.get('ORGM_TEST_ORIGIN') or shutil.which('brave-origin')
seen = []
class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        seen.append((self.path, self.headers.get('Cookie', '')))
        self.send_response(200)
        self.send_header('Content-Type', 'text/html')
        if self.path == '/a': self.send_header('Set-Cookie', 'origin_fixture=shared; Path=/')
        self.end_headers()
        self.wfile.write(('<title>Fixture '+self.path+'</title>Fixture').encode())
    def log_message(self, *args): pass
server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
threading.Thread(target=server.serve_forever, daemon=True).start()
if not parent or not browser or not shutil.which('Hyprland'):
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
    profile = home/'profile'
    profile.mkdir()
    (profile/'Local State').write_text(json.dumps({'brave': {'origin': {'free_tier_accepted': True}}}))
    (home/'hyprland.lua').write_text(
        'hl.monitor({output="",mode="1280x800@60",position="0x0",scale=1})\n'
        'hl.config({animations={enabled=false},debug={disable_logs=false},misc={disable_hyprland_logo=true,disable_splash_rendering=true}})\n')
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
        (cache/'nwg-dock-pinned').write_text('brave-localhost__a-Default\nbrave-localhost__b-Default\n')
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

        for workspace, cls in enumerate(('brave-localhost__a-Default', 'brave-localhost__b-Default'), 1):
            (apps/(cls+'.desktop')).write_text(
                '[Desktop Entry]\nType=Application\nName='+cls+'\n'
                'Icon=utilities-terminal\nStartupWMClass='+cls+'\nExec='+browser+' --user-data-dir='+str(profile)+' --profile-directory=Default --ozone-platform=wayland --no-first-run --app=http://localhost:'+str(server.server_port)+'/'+('a' if workspace == 1 else 'b')+'\n')
            dispatch(f'hl.dsp.focus({{workspace={workspace}}})')
            start(browser, '--user-data-dir='+str(profile), '--profile-directory=Default', '--ozone-platform=wayland', '--no-first-run', '--app=http://localhost:'+str(server.server_port)+'/'+('a' if workspace == 1 else 'b'))
            client = wait(lambda: next((c for c in query('clients') if c['class'] == cls), None), cls)
            addresses[workspace] = client['address']
        assert len({c['pid'] for c in query('clients') if c['class'].startswith('brave-localhost')}) == 1
        wait(lambda: any(path == '/b' and 'origin_fixture=shared' in cookie for path, cookie in seen), 'shared session cookie')
        print('PASS: two identities, one browser process, shared session cookie', flush=True)
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
        # A pinned launcher must reopen its own application after its window closes.
        for target, cls in ((1, 'brave-localhost__a-Default'), (2, 'brave-localhost__b-Default')):
            dispatch('hl.dsp.focus({window="address:'+addresses[target]+'"})')
            dispatch('hl.dsp.window.close()')
            wait(lambda: not any(c['address'] == addresses[target] for c in query('clients')), 'closed fixture')
            time.sleep(.5)
            click_icon(target, 2)
            client = wait(lambda: next((c for c in query('clients') if c['class'] == cls), None), 'reopened correct app')
            addresses[target] = client['address']
            assert query('activewindow')['class'] == cls
            print('PASS: pinned icon reopens its own webapp', target, flush=True)
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
        server.shutdown()
