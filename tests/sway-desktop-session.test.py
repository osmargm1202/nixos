#!/usr/bin/env python3
"""Actual Qt/PipeWire/clipboard/previews in private Sway/HOME/D-Bus endpoints.

ORGM_TEST_POINTER_KEEPER optionally enables real pointer/slider interaction.
Only synthetic PipeWire nodes and a private clipboard database are used.
"""
import hashlib
import json
import os
import re
from pathlib import Path
import shutil
import signal
import statistics
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
shutil.copytree(ROOT/'dotfiles/config/profiles/wayland/.config/quickshell/orgm-wallpapers', ui)
shared = ROOT/'dotfiles/config/profiles/wayland'
shutil.copytree(shared/'.config/quickshell/orgm-desktop', config/'quickshell/orgm-desktop')
shutil.copytree(shared/'.config/orgm-desktop', config/'orgm-desktop')
binary = home/'.local/bin'
binary.mkdir(parents=True)
shutil.copytree(ROOT/'dotfiles/config/profiles/wayland/.local/lib', binary.parent/'lib')
for name in ('orgm-sway', 'orgm-sway-desktop', 'sway-volume-osd', 'sway-mic-volume-osd'):
    shutil.copy2(SOURCE/'.local/bin'/name, binary/name)
shutil.copy2(shared/'.local/bin/orgm-desktop-widgets', binary/'orgm-desktop-widgets')
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
(home/'sway.conf').write_text('xwayland disable\noutput HEADLESS-1 mode 1280x900\nfont pango:monospace 10\ndefault_border none\n'
    f'bindsym Mod1+Tab exec {binary}/orgm-sway-desktop windows\n'
    f'bindsym Mod1+Shift+Tab exec {binary}/orgm-sway-desktop windows prev\n'
    f'bindsym XF86AudioRaiseVolume exec {binary}/sway-volume-osd up\n'
    f'bindsym XF86AudioLowerVolume exec {binary}/sway-volume-osd down\n'
    f'bindsym XF86AudioMute exec {binary}/sway-volume-osd mute\n'
    f'bindsym XF86AudioMicMute exec {binary}/sway-mic-volume-osd mute\n')
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
menu_entry = 'menus.qml'
latencies = {}


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
    result = command('qs', '--path', str(ui/menu_entry), 'ipc', 'call', 'menu', 'status')
    try:
        return json.loads(result.stdout) if result.returncode == 0 else None
    except json.JSONDecodeError:
        return None  # The on-demand Qt process can exit during this IPC call.


def menu(kind):
    started = time.perf_counter()
    process = start(str(binary/'orgm-sway-desktop'), kind)
    wait(lambda: (data := status()) and data['kind'] == kind, kind+' status')
    wait(lambda: any(s.get('namespace') == 'orgm-'+kind for o in json.loads(
         command('swaymsg', '-r', '-t', 'get_outputs').stdout) for s in o.get('layer_shell_surfaces', [])), kind+' layer')
    latencies.setdefault(menu_entry+':'+kind, []).append((time.perf_counter()-started)*1000)
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
    start(str(binary/'orgm-desktop-widgets'), 'daemon')
    def widgets_visible():
        namespaces = {s.get('namespace') for o in json.loads(command('swaymsg', '-r', '-t', 'get_outputs').stdout)
                      for s in o.get('layer_shell_surfaces', [])}
        return {'orgm-desktop-clock', 'orgm-desktop-calendar'} <= namespaces
    wait(widgets_visible, 'desktop widgets alongside menus and preview recorder')
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
    # The persistent overview reuses Qt and maps without capturing on the key path.
    recorder.terminate()
    recorder.wait(timeout=5)
    if pointer:
        command('swaymsg', 'seat seat0 cursor set 10 10').check_returncode()
    resident = start(str(binary/'orgm-sway-desktop'), 'menus-daemon')
    menu_entry = 'daemon.qml'
    ready = wait(lambda: (data := status()) and not data['open'] and data, 'preloaded overview ready')
    pid = ready['pid']
    focused_before = next(w for w in windows() if w['focused'])['id']
    for _ in range(5):
        process = menu('windows')
        assert process.wait(timeout=5) == 0, 'An IPC request returns without waiting for the panel to close'
        assert status()['pid'] == pid, 'Every invocation must reuse the same Qt process'
        close(process)
        wait(lambda: not status()['visible'], 'resident panel fully hidden after cancel')
        assert next(w for w in windows() if w['focused'])['id'] == focused_before
    process = menu('windows')
    tile = next(window for group in status()['overview']['groups'] for window in group['windows'] if window['id'] == str(b))
    if pointer:
        command('swaymsg', f"seat seat0 cursor set {tile['x']+tile['width']/2} {tile['y']+tile['height']/2}").check_returncode()
        wait(lambda: status()['choice'] == str(b), 'resident pointer hover selection')
        key('Return')
    else:
        command('qs', '--path', str(ui/menu_entry), 'ipc', 'call', 'menu', 'close').check_returncode()
    wait(lambda: not status()['visible'], 'resident panel closes after activation')
    if pointer:
        wait(lambda: any(w['focused'] and w['id'] == b for w in windows()), 'resident exact window focus')
    assert resident.poll() is None
    # Reopening during the closing animation must cancel its old dismissal timer.
    process = menu('windows')
    command('qs', '--path', str(ui/menu_entry), 'ipc', 'call', 'menu', 'close').check_returncode()
    process = menu('windows')
    assert status()['open'] and status()['pid'] == pid
    close(process)
    wait(lambda: not status()['visible'], 'resident quick reopen closes cleanly')
    if pointer:
        command('swaymsg', 'seat seat0 cursor set 10 10').check_returncode()
    held = start('wtype', '-M', 'alt', '-P', 'Alt_L', '-k', 'Tab', '-s', '400', '-p', 'Alt_L', '-m', 'alt')
    selection = wait(lambda: (data := status()) and data['open'] and data['choice'], 'warm Alt+Tab maps before a short Alt press ends')
    assert held.wait(timeout=5) == 0
    wait(lambda: not status()['visible'] and any(w['focused'] and str(w['id']) == selection for w in windows()), 'warm Alt release focuses selection')
    cold = statistics.median(latencies['menus.qml:windows'])
    warm = statistics.median(latencies['daemon.qml:windows'])
    print(f'Observed request-to-mapped median: without daemon {cold:.0f}ms; resident {warm:.0f}ms')
    process = menu('audio')
    assert status()['pid'] == pid and len(status()['audio']['outputs']) == 2
    close(process)
    process = menu('control')
    assert status()['pid'] == pid and status()['state']['brightness'] == int((home/'brightness').read_text())
    close(process)
    command('cliphist', 'store', input=image).check_returncode()
    process = menu('clipboard')
    assert status()['pid'] == pid
    key('Return')
    assert process.wait(timeout=5) == 0 and command('wl-paste','--type','image/png').stdout == image
    process = menu('clipboard')
    command('wtype','no-such-entry').check_returncode()
    assert status()['choice'] == ''
    close(process)
    assert status()['items'] == [], 'Hidden clipboard must release its catalog'
    process = menu('clipboard')
    assert status()['choice'], 'Reopening clears the previous clipboard search'
    command('wtype','beta').check_returncode()
    key('Return')
    assert process.wait(timeout=5) == 0 and command('wl-paste','--no-newline').stdout == b'beta fixture text'
    # Different menu requests complete the previous client rather than stacking.
    first_panel = menu('control')
    process = menu('audio')
    assert first_panel.wait(timeout=5) == 0 and status()['kind'] == 'audio'
    close(process)
    for kind in ('control','audio','clipboard'):
        print(f"Observed {kind}: cold {statistics.median(latencies['menus.qml:'+kind]):.0f}ms; resident {statistics.median(latencies['daemon.qml:'+kind]):.0f}ms")
    # OSD controls only this fixture's synthetic PipeWire nodes, even in fullscreen.
    def osd():
        return json.loads(command('qs','--path',str(ui/menu_entry),'ipc','call','osd','status').stdout)
    command('swaymsg', f'[con_id={b}] focus').check_returncode()
    command('swaymsg', 'fullscreen enable').check_returncode()
    command('wpctl','set-volume','@DEFAULT_AUDIO_SINK@','1.49','--limit','1.5').check_returncode()
    command('wpctl','set-mute','@DEFAULT_AUDIO_SINK@','0').check_returncode()
    command('qs','--path',str(ui/menu_entry),'ipc','call','osd','display','output','149','false').check_returncode()
    wait(lambda: osd()['devicePercent']==149, 'native default sink ready')
    key('XF86AudioRaiseVolume')
    wait(lambda: osd()['state']=='maximum' and osd()['percent']==150, 'maximum volume OSD')
    command('grim',str(home/'osd-fullscreen-maximum.png')).check_returncode()
    assert next(w for w in windows() if w['focused'])['id']==b
    assert next(w for w in windows() if w['id']==b)['fullscreen_mode']==1
    key('XF86AudioRaiseVolume')
    assert osd()['active'] and osd()['percent']==150, 'A key press at maximum still refreshes the OSD'
    key('XF86AudioLowerVolume')
    wait(lambda: osd()['percent']==147, 'volume decrease OSD')
    key('XF86AudioMute')
    wait(lambda: osd()['muted'] and osd()['state']=='muted', 'output mute OSD')
    command('grim',str(home/'osd-output-muted.png')).check_returncode()
    key('XF86AudioMute')
    wait(lambda: not osd()['muted'], 'output unmute OSD')
    command('wpctl','set-volume','@DEFAULT_AUDIO_SOURCE@','0.50','--limit','1.5').check_returncode()
    command('wpctl','set-mute','@DEFAULT_AUDIO_SOURCE@','0').check_returncode()
    command('qs','--path',str(ui/menu_entry),'ipc','call','osd','display','input','50','false').check_returncode()
    wait(lambda: osd()['devicePercent']==50, 'native default source ready')
    command(str(binary/'sway-mic-volume-osd'),'up').check_returncode()
    wait(lambda: osd()['target']=='input' and osd()['percent']==53, 'microphone gain OSD')
    key('XF86AudioMicMute')
    wait(lambda: osd()['muted'] and osd()['target']=='input', 'microphone mute OSD')
    command('grim',str(home/'osd-microphone-muted.png')).check_returncode()
    key('XF86AudioMicMute')
    if pointer:
        data=osd()
        slider=data['slider']
        x=(1280-data['width'])/2+slider['x']+slider['leftPadding']+slider['availableWidth']*.25
        y=900-data['bottom']-data['height']+slider['y']+slider['height']/2
        command('swaymsg', f'seat seat0 cursor set {x} {y}').check_returncode()
        command('swaymsg', 'seat seat0 cursor press button1').check_returncode()
        time.sleep(1.6)
        assert osd()['active'], 'The slider must not disappear while held'
        command('swaymsg', 'seat seat0 cursor release button1').check_returncode()
        wait(lambda: 20<osd()['percent']<60 and abs(osd()['devicePercent']-osd()['percent'])<=1, 'interactive microphone slider')
        assert next(w for w in windows() if w['focused'])['id']==b, 'OSD slider cannot take fullscreen keyboard focus'
    # Verify that the rendered OSD is above the actual blue fullscreen content.
    data=osd()
    capture=command('grim','-t','ppm','-').stdout
    header=re.match(rb'P6\s+(\d+)\s+(\d+)\s+255\s',capture)
    x=int((1280-data['width'])/2+8);y=int(900-data['bottom']-data['height']+data['height']/2)
    offset=header.end()+(y*int(header[1])+x)*3
    assert capture[offset:offset+3]!=bytes([0,0,255]), 'OSD must draw above the fullscreen app'
    wait(lambda: not osd()['visible'], 'OSD automatically hides')
    # An unchanged value at zero must be announced too.
    command('wpctl','set-volume','@DEFAULT_AUDIO_SINK@','0').check_returncode()
    command('qs','--path',str(ui/menu_entry),'ipc','call','osd','display','output','0','false').check_returncode()
    wait(lambda: osd()['devicePercent']==0, 'zero default sink ready')
    command(str(binary/'sway-volume-osd'),'down').check_returncode()
    assert osd()['active'] and osd()['state']=='zero' and osd()['percent']==0
    command('swaymsg','fullscreen enable global').check_returncode()
    command('qs','--path',str(ui/menu_entry),'ipc','call','osd','display','output','0','false').check_returncode()
    assert next(w for w in windows() if w['id']==b)['fullscreen_mode']==2
    command('swaymsg','fullscreen disable').check_returncode()
    # The native Sway focus integration chooses the current monitor.
    command('swaymsg','create_output').check_returncode()
    wait(lambda: len(json.loads(command('swaymsg','-r','-t','get_outputs').stdout))==2, 'second OSD monitor')
    command('swaymsg','output HEADLESS-2 mode 1280x900 pos 1280 0').check_returncode()
    command('swaymsg','focus output HEADLESS-2').check_returncode()
    command('qs','--path',str(ui/menu_entry),'ipc','call','osd','display','output','0','false').check_returncode()
    wait(lambda: osd()['screen']=='HEADLESS-2', 'OSD follows focused monitor')
    command('swaymsg','focus output HEADLESS-1').check_returncode()
    command('swaymsg','output HEADLESS-2 disable').check_returncode()
    command('qs','--path',str(ui/menu_entry),'ipc','call','osd','hide').check_returncode()
    replacement=config/'waybar/new-palette.css'
    replacement.write_text('@define-color base #071422;\n@define-color blue #12ab34;\n')
    replacement.replace(config/'waybar/orgm-current.css')
    command('qs','--path',str(ui/menu_entry),'ipc','call','osd','display','output','20','false').check_returncode()
    wait(lambda: osd()['accent']=='#12ab34', 'OSD palette refresh after atomic profile update')
    resident.terminate()
    resident.wait(timeout=5)
    menu_entry = 'menus.qml'
    process = menu('windows')
    close(process)
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
