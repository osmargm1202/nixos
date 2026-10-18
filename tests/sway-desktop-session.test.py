#!/usr/bin/env python3
"""Actual Qt/PipeWire/clipboard/previews in private Sway/HOME/D-Bus endpoints.

ORGM_TEST_POINTER_KEEPER optionally enables real pointer/slider interaction.
Only synthetic PipeWire nodes and a private clipboard database are used.
"""
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import struct
import subprocess
import tempfile
import time
import zlib

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT/'dotfiles/config/profiles/sway'
home = Path(tempfile.mkdtemp(prefix='sway-desktop-session-'))
runtime = home/'runtime'
runtime.mkdir(mode=0o700)
config = home/'.config'
ui = config/'quickshell/orgm-wallpapers'
shutil.copytree(SOURCE/'.config/quickshell/orgm-wallpapers', ui)
binary = home/'.local/bin'
binary.mkdir(parents=True)
for name in ('orgm-sway', 'orgm-sway-desktop'):
    shutil.copy2(SOURCE/'.local/bin'/name, binary/name)
(home/'brightness').write_text('50')
(home/'dnd').write_text('false')
(binary/'brightnessctl').write_text('#!/usr/bin/env python3\nfrom pathlib import Path\nimport sys\n'
    f'p=Path({str(home/"brightness")!r})\n'
    'if "set" in sys.argv:p.write_text(sys.argv[-1].removesuffix("%"))\n'
    'else:print("fixture,backlight,50,"+p.read_text()+"%,100")\n')
(binary/'swaync-client').write_text('#!/usr/bin/env python3\nfrom pathlib import Path\nimport sys\n'
    f'p=Path({str(home/"dnd")!r})\n'
    'if "--get-dnd" in sys.argv:print(p.read_text())\n'
    'else:p.write_text("false" if p.read_text()=="true" else "true")\n')
for name in ('brightnessctl', 'swaync-client'):
    (binary/name).chmod(0o755)
(config/'waybar').mkdir()
(config/'waybar/orgm-current.css').write_text('@define-color base #071422;\n@define-color blue #71b7ff;\n')
(home/'sway.conf').write_text('output HEADLESS-1 mode 1280x900\nfont pango:monospace 10\ndefault_border none\n'
    f'bindsym Mod1+Tab exec {binary}/orgm-sway-desktop windows\n'
    f'bindsym Mod1+Shift+Tab exec {binary}/orgm-sway-desktop windows prev\n')
env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(config), XDG_STATE_HOME=str(home/'.local/state'),
           XDG_CACHE_HOME=str(home/'.cache'), XDG_DATA_HOME=str(home/'.local/share'),
           XDG_RUNTIME_DIR=str(runtime), PIPEWIRE_RUNTIME_DIR=str(runtime), PIPEWIRE_REMOTE='pipewire-0',
           PATH=str(binary)+os.pathsep+os.environ['PATH'], XDG_CURRENT_DESKTOP='sway', QT_QPA_PLATFORM='wayland',
           WLR_BACKENDS='headless', WLR_HEADLESS_OUTPUTS='1', WLR_RENDERER='gles2', WLR_RENDERER_ALLOW_SOFTWARE='1')
for key in ('DISPLAY', 'SWAYSOCK', 'WAYLAND_DISPLAY', 'WAYLAND_SOCKET', 'DBUS_SESSION_BUS_ADDRESS',
            'ORGM_VISUAL_PROFILE_STATE_DIR', 'ORGM_VISUAL_PROFILE_PICTURES_ROOT', 'QS_CONFIG_PATH', 'QS_CONFIG_NAME'):
    env.pop(key, None)
intel = Path('/dev/dri/by-path/pci-0000:00:02.0-render')
if intel.exists():
    env['WLR_RENDER_DRM_DEVICE'] = str(intel.resolve())
log = (home/'session.log').open('w')
compositor = subprocess.Popen(['dbus-run-session', '--', 'sh', '-c',
    'printf "%s" "$DBUS_SESSION_BUS_ADDRESS" > "$1"; shift; exec "$@"', '_', str(home/'bus'),
    shutil.which('sway'), '-c', str(home/'sway.conf')], env=env, stdout=log, stderr=log, start_new_session=True)
children = []


def start(*args, **kwargs):
    process = subprocess.Popen(args, env=env, stdout=log, stderr=log, start_new_session=True, **kwargs)
    children.append(process)
    return process


def command(*args, **kwargs):
    return subprocess.run(args, env=env, capture_output=True, timeout=10, **kwargs)


def wait(probe, label):
    deadline = time.monotonic()+15
    while time.monotonic() < deadline:
        result = probe()
        if result:
            return result
        assert compositor.poll() is None, 'Private compositor exited'
        time.sleep(.06)
    (home/'last-status.json').write_text(json.dumps(status(), indent=2))
    (home/'last-pipewire.json').write_bytes(command('pw-dump').stdout)
    raise AssertionError('Timeout: '+label+'; logs: '+str(home/'session.log'))


def status():
    result = command('qs', '--path', str(ui/'menus.qml'), 'ipc', 'call', 'menu', 'status')
    try:
        return json.loads(result.stdout) if result.returncode == 0 else None
    except json.JSONDecodeError:
        return None  # The on-demand Qt process can exit during this IPC call.


def menu(kind):
    process = start(str(binary/'orgm-sway-desktop'), kind)
    wait(lambda: (data := status()) and data['kind'] == kind, kind+' status')
    wait(lambda: any(s.get('namespace') == 'orgm-'+kind for o in json.loads(
         command('swaymsg', '-r', '-t', 'get_outputs').stdout) for s in o.get('layer_shell_surfaces', [])), kind+' layer')
    time.sleep(.3)
    return process


def key(name):
    command('wtype', '-k', name).check_returncode()
    time.sleep(.15)


def click(x, y):
    for operation in (f'set {x} {y}', 'press button1', 'release button1'):
        command('swaymsg', 'seat seat0 cursor '+operation).check_returncode()
    time.sleep(.2)


def close(process):
    key('Escape')
    assert process.wait(timeout=5) == 0


def windows():
    def walk(node):
        result = [node] if node.get('app_id') else []
        for child in node.get('nodes', [])+node.get('floating_nodes', []):
            result.extend(walk(child))
        return result
    return walk(json.loads(command('swaymsg', '-r', '-t', 'get_tree').stdout))


try:
    env['SWAYSOCK'] = str(wait(lambda: next(runtime.glob('sway-ipc.*.sock'), None), 'IPC'))
    env['WAYLAND_DISPLAY'] = wait(lambda: next((p.name for p in runtime.glob('wayland-*') if p.is_socket()), None), 'Wayland')
    env['DBUS_SESSION_BUS_ADDRESS'] = (home/'bus').read_text()
    start('wtype', '-s', '120000')
    pointer = os.environ.get('ORGM_TEST_POINTER_KEEPER')
    if pointer:
        start(pointer, stdin=subprocess.PIPE)
    time.sleep(.2)
    # A separate PipeWire core plus policy-only WirePlumber: no hardware monitors.
    pw = start('pipewire')
    wait(lambda: (runtime/'pipewire-0').is_socket(), 'private PipeWire core')
    start('wireplumber', '--profile', 'policy')
    for name, media in (('menu-speaker-a', 'Audio/Sink'), ('menu-speaker-b', 'Audio/Sink'), ('menu-mic', 'Audio/Source')):
        args = '{ factory.name = support.null-audio-sink node.name = '+name+' node.description = '+name+' media.class = '+media+' object.linger = true audio.position = [ FL FR ] }'
        command('pw-cli', 'create-node', 'adapter', args).check_returncode()
    process = menu('audio')
    audio = wait(lambda: (data := status()['audio']) and len(data['outputs']) == 2 and len(data['inputs']) == 1 and data, 'synthetic audio devices')
    command('grim', str(home/'audio.png')).check_returncode()
    if pointer:
        # The panel is 700x660, centered at (290,120). Select the second sink.
        click(540, 450)
        wait(lambda: any(n['name'] == 'menu-speaker-b' and n['selected'] for n in status()['audio']['outputs']), 'default output selection')
        click(875, 450)
        wait(lambda: next(n for n in status()['audio']['outputs'] if n['name'] == 'menu-speaker-b')['muted'], 'device mute')
        click(600, 503)
        wait(lambda: next(n for n in status()['audio']['outputs'] if n['name'] == 'menu-speaker-b')['volume'] < 1, 'device volume slider')
    close(process)
    process = menu('control')
    assert status()['state']['brightness'] == 50
    assert status()['state']['dnd'] is False
    command('grim', str(home/'control.png')).check_returncode()
    if pointer:
        click(800, 339)
        wait(lambda: status()['state']['dnd'] is True, 'DND toggle')
        click(620, 186)
        wait(lambda: status()['state']['brightness'] != 50, 'brightness slider')
    close(process)
    # Clipboard database and Wayland clipboard belong only to this fixture.
    command('cliphist', 'store', input=b'alpha fixture text').check_returncode()
    command('cliphist', 'store', input=b'beta fixture text').check_returncode()
    def chunk(kind, data):
        return struct.pack('!I', len(data))+kind+data+struct.pack('!I', zlib.crc32(kind+data))
    image = b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR', struct.pack('!2I5B', 8, 8, 8, 2, 0, 0, 0))
    image += chunk(b'IDAT', zlib.compress((b'\0'+bytes([255, 0, 0])*8)*8))+chunk(b'IEND', b'')
    command('cliphist', 'store', input=image).check_returncode()
    process = menu('clipboard')
    assert len(status()['items']) == 3
    assert any(item['preview'] for item in status()['items'])
    command('grim', str(home/'clipboard.png')).check_returncode()
    command('wtype', 'beta').check_returncode()
    key('Return')
    assert process.wait(timeout=5) == 0
    assert command('wl-paste', '--no-newline').stdout == b'beta fixture text'
    process = menu('clipboard')
    key('Return')
    assert process.wait(timeout=5) == 0
    assert command('wl-paste', '--type', 'image/png').stdout == image
    process = menu('clipboard')
    key('Delete')
    wait(lambda: len(command('cliphist', 'list').stdout.splitlines()) == 2, 'history deletion')
    close(process)
    # Capture one actual window, then hide it on another workspace and keep its thumbnail.
    first = start('kitty', '--config', 'NONE', '--class', 'menu-window-a', '-o', 'linux_display_server=wayland', '-o', 'background=#ff0000', '-e', 'sleep', '120')
    wait(lambda: any(w['app_id'] == 'menu-window-a' for w in windows()), 'first window')
    time.sleep(.4)
    recorder = start(str(binary/'orgm-sway-desktop'), 'previews')
    cache = runtime/('orgm-sway-previews-'+hashlib.sha256(env['SWAYSOCK'].encode()).hexdigest()[:20])
    a = next(w['id'] for w in windows() if w['app_id'] == 'menu-window-a')
    wait(lambda: (cache/(str(a)+'.png')).exists(), 'first real thumbnail')
    command('swaymsg', 'workspace 2').check_returncode()
    second = start('kitty', '--config', 'NONE', '--class', 'menu-window-b', '-o', 'linux_display_server=wayland', '-o', 'background=#0000ff', '-e', 'sleep', '120')
    wait(lambda: any(w['app_id'] == 'menu-window-b' for w in windows()), 'second window')
    b = next(w['id'] for w in windows() if w['app_id'] == 'menu-window-b')
    wait(lambda: (cache/(str(b)+'.png')).exists(), 'second real thumbnail')
    command('swaymsg', 'workspace 1').check_returncode()
    process = menu('windows')
    assert status()['choice'] == str(b), status()
    overview = status()['overview']
    assert (overview['columns'], overview['rows']) == (2, 1), overview
    assert [group['name'] for group in overview['groups']] == ['1', '2']
    assert all(item['preview'] for item in status()['items'])
    assert all((cache/(item['id']+'.png')).stat().st_mode & 0o777 == 0o600 for item in status()['items'])
    command('grim', str(home/'windows.png')).check_returncode()
    key('Return')
    assert process.wait(timeout=5) == 0
    assert next(w for w in windows() if w['focused'])['id'] == b
    # Exercise the actual compositor binding and accept on releasing Alt.
    held = start('wtype', '-M', 'alt', '-P', 'Alt_L', '-k', 'Tab', '-s', '5000', '-p', 'Alt_L', '-m', 'alt')
    wait(lambda: (data := status()) and data['kind'] == 'windows' and data['choice'] == str(a), 'Alt+Tab mapped while Alt is held')
    assert held.wait(timeout=10) == 0
    wait(lambda: status() is None and any(w['focused'] and w['id'] == a for w in windows()), 'Alt release switches window')
    held = start('wtype', '-M', 'alt', '-P', 'Alt_L', '-k', 'Tab', '-k', 'Tab', '-s', '5000', '-p', 'Alt_L', '-m', 'alt')
    wait(lambda: (data := status()) and data['kind'] == 'windows' and data['choice'] == str(a), 'repeated Alt+Tab mapped while Alt is held')
    assert held.wait(timeout=10) == 0
    wait(lambda: status() is None and any(w['focused'] and w['id'] == a for w in windows()), 'rapid repeated Alt+Tab uses one popup')
    if pointer:
        extra = {}
        for number, color in ((10, '#00ff00'), (3, '#ffff00'), (7, '#ff00ff')):
            command('swaymsg', 'workspace number '+str(number)).check_returncode()
            name = 'menu-window-'+str(number)
            start('kitty', '--config', 'NONE', '--class', name, '-o', 'linux_display_server=wayland',
                  '-o', 'background='+color, '-e', 'sleep', '120')
            wait(lambda: any(w['app_id'] == name for w in windows()), 'additional workspace window')
            extra[number] = next(w['id'] for w in windows() if w['app_id'] == name)
            wait(lambda: (cache/(str(extra[number])+'.png')).exists(), 'additional workspace thumbnail')
        command('swaymsg', 'workspace number 3').check_returncode()
        start('kitty', '--config', 'NONE', '--class', 'menu-window-3-second', '-o', 'linux_display_server=wayland',
              '-o', 'background=#00ffff', '-e', 'sleep', '120')
        wait(lambda: any(w['app_id'] == 'menu-window-3-second' for w in windows()), 'second window in one workspace')
        second_in_three = next(w['id'] for w in windows() if w['app_id'] == 'menu-window-3-second')
        wait(lambda: (cache/(str(second_in_three)+'.png')).exists(), 'second same-workspace thumbnail')
        process = menu('windows')
        overview = status()['overview']
        assert (overview['columns'], overview['rows']) == (3, 2), overview
        groups = overview['groups']
        assert [group['name'] for group in groups] == ['1', '2', '3', '7', '10'], overview
        assert len(groups) == 5 and groups[0]['y'] == groups[2]['y'] and groups[3]['y'] > groups[0]['y']
        assert len(next(group for group in groups if group['name'] == '3')['windows']) == 2
        command('grim', str(home/'windows-five-workspaces.png')).check_returncode()
        click(groups[0]['x']+30, groups[0]['y']+24)
        assert process.wait(timeout=5) == 0
        assert next(w for w in windows() if w['focused'])['id'] == a, 'Workspace header must open its desktop'
        process = menu('windows')
        group = next(group for group in status()['overview']['groups'] if group['name'] == '3')
        tile = next(window for window in group['windows'] if window['id'] == str(extra[3]))
        click(tile['x']+tile['width']/2, tile['y']+tile['height']/2)
        assert process.wait(timeout=5) == 0
        assert next(w for w in windows() if w['focused'])['id'] == extra[3], 'Tile must focus that exact window, not the last focused window'
    log.flush()
    diagnostics = (home/'session.log').read_text()
    assert 'TypeError:' not in diagnostics and 'ReferenceError:' not in diagnostics, diagnostics
    print('PASS: real control/audio, isolated clipboard and Alt+Tab workspace grids with exact window selection')
    print('Private logs/screenshots: '+str(home))
finally:
    for child in reversed(children):
        if child.poll() is None:
            os.killpg(child.pid, signal.SIGTERM)
            child.wait(timeout=5)
    if compositor.poll() is None:
        os.killpg(compositor.pid, signal.SIGTERM)
    compositor.wait(timeout=10)
    log.close()
