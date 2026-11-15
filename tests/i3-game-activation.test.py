#!/usr/bin/env python3
"""Real X11 activation requests, on a private Xvfb/i3 display only."""
import ctypes as C
import ctypes.util
import importlib.util
import json
import os
from pathlib import Path
import selectors
import signal
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT/'nixos/profiles/i3/game-activation.py'
spec = importlib.util.spec_from_file_location('game_activation', HELPER)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

for cls in ['dota2', 'steam_app_570', 'steam_app_123', 'gamescope', 'EtG.x86_64']:
    event = {'change': 'urgent', 'container': {'id': 42, 'urgent': True, 'window_properties': {'class': cls}}}
    assert module.requested_game(event) == 42
    for field, value in [('change', 'focus'), ('change', 'title')]:
        assert module.requested_game({**event, field: value}) is None
for cls in ['steam', 'Steam', 'steamwebhelper', 'steam_app_bad', 'not-dota2', 'firefox', 'kitty', 'dota2; focus']:
    assert module.requested_game({'change': 'urgent', 'container': {'id': 42, 'urgent': True, 'window_properties': {'class': cls}}}) is None
assert module.requested_game({'change': 'urgent', 'container': {'id': '1] focus', 'urgent': True, 'window_properties': {'class': 'dota2'}}}) is None
assert module.requested_game({'change': 'urgent', 'container': {'id': 42, 'urgent': False, 'window_properties': {'class': 'dota2'}}}) is None
assert module.requested_game({'change': 'urgent', 'container': None}) is None

def identity(path):
    s = path.lstat()
    return s.st_ino, s.st_mode

original = {p: identity(p) for p in Path('/tmp/.X11-unix').glob('*')}
with tempfile.TemporaryDirectory(prefix='i3-game-activation-') as temporary:
    t = Path(temporary)
    env = dict(os.environ, HOME=str(t), XDG_CONFIG_HOME=str(t/'config'),
               XDG_RUNTIME_DIR=str(t), XDG_CURRENT_DESKTOP='i3', XDG_SESSION_TYPE='x11',
               DBUS_SESSION_BUS_ADDRESS='unix:path='+str(t/'no-session-bus'))
    for key in ['DISPLAY', 'XAUTHORITY', 'I3SOCK', 'WAYLAND_DISPLAY', 'SWAYSOCK', 'HYPRLAND_INSTANCE_SIGNATURE']:
        env.pop(key, None)
    config = t/'i3.conf'
    ipc = t/'ipc.sock'
    config.write_text(f'font pango:monospace 10\nipc-socket {ipc}\nfocus_follows_mouse no\nfocus_on_window_activation smart\nforce_display_urgency_hint 0 ms\n')
    log = (t/'session.log').open('w')
    children = []
    display = None

    def start(args, **kwargs):
        p = subprocess.Popen(args, env=env, stderr=log, start_new_session=True, **kwargs)
        children.append(p)
        return p

    def cmd(command):
        reply = json.loads(subprocess.check_output(['i3-msg', '-r', '-s', str(ipc), command], env=env, text=True))
        assert all(r['success'] for r in reply), reply

    def tree():
        return json.loads(subprocess.check_output(['i3-msg', '-s', str(ipc), '-t', 'get_tree'], env=env, text=True))

    def nodes(n):
        yield n
        for child in n.get('nodes', []) + n.get('floating_nodes', []):
            yield from nodes(child)

    def focused():
        return next((n.get('window_properties', {}).get('class') for n in nodes(tree()) if n.get('focused') and n.get('window')), None)

    def wait(probe, label):
        deadline = time.monotonic()+8
        while time.monotonic() < deadline:
            result = probe()
            if result:
                return result
            time.sleep(.03)
        raise AssertionError(label+'\n'+(t/'session.log').read_text()[-3000:])

    try:
        xserver = start(['Xvfb', '-displayfd', '1', '-screen', '0', '1024x768x24', '-nolisten', 'tcp'], stdout=subprocess.PIPE, text=True)
        env['DISPLAY'] = ':'+xserver.stdout.readline().strip()
        wm = start(['i3', '-c', str(config)], stdout=log)
        wait(ipc.exists, 'private i3 IPC')
        version = json.loads(subprocess.check_output(['i3-msg', '-s', str(ipc), '-t', 'get_version'], env=env, text=True))
        assert version['loaded_config_file_name'] == str(config)
        listener = start([sys.executable, str(HELPER)], stdout=subprocess.PIPE, text=True)
        ready = selectors.DefaultSelector();ready.register(listener.stdout, selectors.EVENT_READ)
        assert ready.select(8), 'activation listener not ready'
        assert 'listening' in listener.stdout.readline()

        library = C.util.find_library('X11') or next(iter(
            list(Path('/nix/store').glob('*libX11-*/lib/libX11.so.6'))
            + list(Path('/nix/store').glob('*libx11-*/lib/libX11.so.6'))))
        x = C.CDLL(str(library))
        D = C.c_void_p;W = C.c_ulong
        x.XOpenDisplay.argtypes = [C.c_char_p];x.XOpenDisplay.restype = D
        x.XDefaultRootWindow.argtypes = [D];x.XDefaultRootWindow.restype = W
        x.XCreateSimpleWindow.argtypes = [D,W,C.c_int,C.c_int,C.c_uint,C.c_uint,C.c_uint,W,W];x.XCreateSimpleWindow.restype = W
        x.XMapWindow.argtypes = [D,W];x.XFlush.argtypes = [D];x.XCloseDisplay.argtypes = [D]
        x.XInternAtom.argtypes = [D,C.c_char_p,C.c_int];x.XInternAtom.restype = W
        x.XSendEvent.argtypes = [D,W,C.c_int,C.c_long,D]
        class Hint(C.Structure):
            _fields_ = [('name', C.c_char_p), ('cls', C.c_char_p)]
        x.XSetClassHint.argtypes = [D,W,C.POINTER(Hint)]
        class Data(C.Union):
            _fields_ = [('b', C.c_char*20), ('s', C.c_short*10), ('l', C.c_long*5)]
        class Message(C.Structure):
            _fields_ = [('type',C.c_int),('serial',W),('send_event',C.c_int),('display',D),('window',W),('message_type',W),('format',C.c_int),('data',Data)]
        class Event(C.Union):
            _fields_ = [('message', Message), ('pad', C.c_long*24)]
        display = x.XOpenDisplay(env['DISPLAY'].encode());assert display
        root = x.XDefaultRootWindow(display)
        windows = {}
        for index, name in enumerate(['game-control', 'dota2', 'steam_app_570', 'steam', 'steam_app_bad', 'firefox']):
            window = x.XCreateSimpleWindow(display, root, 0, 0, 250, 150, 0, 0, 0)
            hint = Hint(name.encode(), name.encode());x.XSetClassHint(display, window, C.byref(hint))
            x.XMapWindow(display, window);x.XFlush(display)
            wait(lambda: any(n.get('window') == window for n in nodes(tree())), 'map '+name)
            windows[name] = window
            cmd(f'[id={window}] move container to workspace number {index+1}')

        def focus(name):
            cmd(f'[id={windows[name]}] focus')
            wait(lambda: focused() == name, 'focus '+name)

        def request(name):
            event = Event()
            event.message = Message(type=33, send_event=1, display=display, window=windows[name],
                                    message_type=x.XInternAtom(display,b'_NET_ACTIVE_WINDOW',0), format=32)
            event.message.data.l[0] = 1
            assert x.XSendEvent(display,root,0,(1<<20)|(1<<19),C.byref(event))
            x.XFlush(display)

        for name in ['dota2', 'steam_app_570', 'dota2']:
            focus('game-control');request(name)
            wait(lambda: focused() == name, 'activation across workspaces: '+name)
        # Background games do not regain focus merely because the user Alt+Tabs.
        focus('game-control');time.sleep(.15)
        assert focused() == 'game-control'
        for name in ['steam', 'steam_app_bad', 'firefox']:
            request(name);time.sleep(.15)
            assert focused() == 'game-control', 'non-game stole focus: '+name
        focus('dota2');cmd(f'[id={windows["dota2"]}] fullscreen enable');focus('game-control')
        request('dota2');wait(lambda: focused() == 'dota2', 'fullscreen activation')
        assert next(n for n in nodes(tree()) if n.get('window') == windows['dota2'])['fullscreen_mode'] == 1
        # Restart only the private i3; the subscriber must discover/reconnect.
        cmd('restart')
        assert ready.select(8), 'listener did not reconnect after private restart'
        assert 'listening' in listener.stdout.readline()
        focus('game-control');request('steam_app_570')
        wait(lambda: focused() == 'steam_app_570', 'activation after restart')
        print('PASS: repeated game requests focus across workspaces/fullscreen; Steam and other apps excluded; no focus loop; reconnect after restart')
    finally:
        if display:
            x.XCloseDisplay(display)
        for p in reversed(children):
            if p.poll() is None:
                os.killpg(p.pid, signal.SIGTERM)
                try:p.wait(timeout=5)
                except subprocess.TimeoutExpired:os.killpg(p.pid,signal.SIGKILL);p.wait()
        log.close()
for p, value in original.items():
    assert identity(p) == value, 'original X11 socket changed'
print('PASS: original display/game untouched')
