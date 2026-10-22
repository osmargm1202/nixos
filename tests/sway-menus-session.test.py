#!/usr/bin/env python3
"""Real menus/launcher in private Sway/Wayland/HOME/D-Bus; power commands stubbed."""
import json
import os
from pathlib import Path
import re
import shutil
import signal
import struct
import subprocess
import tempfile
import time
import zlib

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT/'dotfiles/config/profiles/sway'
home = Path(tempfile.mkdtemp(prefix='sway-menus-session-'))
runtime = home/'runtime'
runtime.mkdir(mode=0o700)
config = home/'.config'
ui = config/'quickshell/orgm-wallpapers'
shutil.copytree(ROOT/'dotfiles/config/profiles/wayland/.config/quickshell/orgm-wallpapers', ui)
shutil.copytree(SOURCE/'.config/rofi-sway', config/'rofi-sway')
binary = home/'.local/bin'
binary.mkdir(parents=True)
shutil.copytree(ROOT/'dotfiles/config/profiles/wayland/.local/lib', binary.parent/'lib')
for name in ('orgm-sway', 'orgm-sway-desktop', 'sway-app-launcher', 'sway-rofi-lib'):
    shutil.copy2(SOURCE/'.local/bin'/name, binary/name)
shutil.copy2(ROOT/'dotfiles/config/profiles/wayland/.local/bin/orgm-rofi', binary/'orgm-rofi')
calls = home/'calls'
calls.touch()
for name in ('orgm-qylock', 'systemctl', 'orgm-visual-profile'):
    stub = binary/name
    stub.write_text('#!/usr/bin/env python3\nimport json,pathlib,sys\n'
        f'with pathlib.Path({str(calls)!r}).open("a") as f:f.write(json.dumps([pathlib.Path(sys.argv[0]).name,*sys.argv[1:]])+"\\n")\n')
    stub.chmod(0o755)
state = home/'.local/state/orgm-visual-profile'
state.mkdir(parents=True)
(state/'current').write_text('slc\n')


def chunk(kind, data):
    return struct.pack('!I', len(data))+kind+data+struct.pack('!I', zlib.crc32(kind+data))


for profile, color in (('slc', [255, 0, 0]), ('orgm', [0, 255, 0]), ('osmar', [0, 0, 255])):
    image = home/'Pictures'/profile/'saved.png'
    image.parent.mkdir(parents=True)
    image.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR', struct.pack('!2I5B', 8, 8, 8, 2, 0, 0, 0))
                      +chunk(b'IDAT', zlib.compress((b'\0'+bytes(color)*8)*8))+chunk(b'IEND', b''))
    saved = state/'profiles'/profile/'wallpaper'
    saved.parent.mkdir(parents=True)
    saved.write_text(str(image)+'\n')
(config/'waybar').mkdir()
(config/'waybar/orgm-current.css').write_text('@define-color base #071422;\n@define-color blue #71b7ff;\n')
(home/'sway.conf').write_text('xwayland disable\noutput HEADLESS-1 mode 1280x720\nfont pango:monospace 10\n')
env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(config), XDG_STATE_HOME=str(home/'.local/state'),
           XDG_CACHE_HOME=str(home/'.cache'), XDG_DATA_HOME=str(home/'.local/share'),
           XDG_RUNTIME_DIR=str(runtime), PATH=str(binary)+os.pathsep+os.environ['PATH'],
           XDG_CURRENT_DESKTOP='sway', QT_QPA_PLATFORM='wayland', WLR_BACKENDS='headless',
           WLR_HEADLESS_OUTPUTS='1', WLR_RENDERER='gles2', WLR_RENDERER_ALLOW_SOFTWARE='1')
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
resident_mode = bool(os.environ.get('ORGM_TEST_RESIDENT_MENUS'))
menu_entry = 'daemon.qml' if resident_mode else 'menus.qml'
service_pid = None


def command(*args):
    return subprocess.run(args, env=env, capture_output=True, text=True, timeout=10)


def wait(probe, label):
    deadline = time.monotonic()+12
    while time.monotonic() < deadline:
        found = probe()
        if found:
            return found
        assert compositor.poll() is None, 'Private compositor exited'
        time.sleep(.05)
    raise AssertionError('Timeout: '+label+'; logs: '+str(home/'session.log'))


def status():
    result = command('qs', '--path', str(ui/menu_entry), 'ipc', 'call', 'menu', 'status')
    try:
        return json.loads(result.stdout) if result.returncode == 0 else None
    except json.JSONDecodeError:
        return None


def start(kind):
    process = subprocess.Popen([str(binary/'orgm-sway'), kind], env=env, stdout=log, stderr=log, start_new_session=True)
    children.append(process)
    wait(lambda: (data := status()) and data['kind'] == kind, kind+' IPC')
    namespace = 'orgm-power' if kind == 'power' else 'orgm-profiles'
    wait(lambda: any(s.get('namespace') == namespace for o in json.loads(
         command('swaymsg', '-r', '-t', 'get_outputs').stdout) for s in o.get('layer_shell_surfaces', [])), 'menu surface')
    time.sleep(.25)
    if service_pid: assert status()['pid'] == service_pid
    return process


def key(name):
    command('wtype', '-k', name).check_returncode()
    time.sleep(.15)


def recorded():
    return [json.loads(line) for line in calls.read_text().splitlines()]


def bar_pixel():
    data = subprocess.check_output(['grim', '-t', 'ppm', '-'], env=env, stderr=subprocess.PIPE, timeout=5)
    header = re.match(rb'P6\s+(\d+)\s+(\d+)\s+255\s', data)
    offset = header.end()+(2*int(header[1])+2)*3
    return tuple(data[offset:offset+3])


try:
    env['SWAYSOCK'] = str(wait(lambda: next(runtime.glob('sway-ipc.*.sock'), None), 'IPC'))
    env['WAYLAND_DISPLAY'] = wait(lambda: next((p.name for p in runtime.glob('wayland-*') if p.is_socket()), None), 'Wayland')
    env['DBUS_SESSION_BUS_ADDRESS'] = (home/'bus').read_text()
    keeper = subprocess.Popen(['wtype', '-s', '120000'], env=env, stdout=log, stderr=log, start_new_session=True)
    children.append(keeper)
    time.sleep(.15)
    if resident_mode:
        daemon = subprocess.Popen([str(binary/'orgm-sway-desktop'), 'menus-daemon'], env=env, stdout=log, stderr=log, start_new_session=True)
        children.append(daemon)
        service_pid = wait(lambda: (data := status()) and data['pid'], 'resident menus ready')
        assert len(status()['preloaded']) == 7
    process = start('power')
    assert status()['choice'] == 'Bloquear'
    assert status()['colors']['accent'] == '#71b7ff'
    key('5')
    key('Return')
    assert status()['confirming'] is True and recorded() == []
    command('grim', str(home/'power-confirm.png')).check_returncode()
    key('Escape')
    assert process.wait(timeout=5) == 0 and recorded() == []
    process = start('power')
    assert status()['choice'] == 'Bloquear' and not status()['confirming'], 'Confirmation must reset after cancellation'
    key('5')
    key('Return')
    key('Return')
    assert process.wait(timeout=5) == 0
    assert recorded() == [['systemctl', 'poweroff']], recorded()
    process = start('power')
    key('2')
    key('Return')
    assert process.wait(timeout=5) == 0
    assert recorded()[-2:] == [['orgm-qylock', 'lock'], ['systemctl', 'suspend']]
    process = start('profiles')
    data = status()
    assert data['choice'] == 'slc' and all(item['preview'].startswith('file:///') for item in data['items'])
    command('grim', str(home/'profiles.png')).check_returncode()
    key('Right')
    assert status()['choice'] == 'orgm'
    key('Return')
    assert process.wait(timeout=5) == 0
    assert recorded()[-1] == ['orgm-visual-profile', 'set', 'orgm']
    (state/'current').write_text('orgm\n')
    process = start('profiles')
    assert status()['choice'] == 'orgm', 'Current profile must be selected on open'
    before = recorded()
    key('Escape')
    assert process.wait(timeout=5) == 0 and recorded() == before
    if resident_mode:
        # Wallpaper application stays in the picker, including failure/retry.
        wallpaper_backend = binary/'wallpaper-test-backend'
        failure = home/'wallpaper-fail'
        wallpaper_backend.write_text('#!/usr/bin/env python3\nimport json,pathlib,sys,runpy\n'
            f'if sys.argv[1]=="wallpaper-preview":print(runpy.run_path({str(binary/"orgm-sway")!r})["wallpaper_preview"](pathlib.Path(sys.argv[2])).as_uri());sys.exit(0)\n'
            f'if pathlib.Path({str(failure)!r}).exists():print("fixture wallpaper failure",file=sys.stderr);sys.exit(1)\n'
            f'with pathlib.Path({str(calls)!r}).open("a") as f:f.write(json.dumps(["wallpaper",*sys.argv[1:]])+"\\n")\n')
        wallpaper_backend.chmod(0o755)
        items = [dict(path=str(home/'Pictures'/p/'saved.png'), url=(home/'Pictures'/p/'saved.png').as_uri(), name=p, kind='image') for p in ('slc','orgm')]
        catalog = dict(kind='wallpaper', backend=str(wallpaper_backend), profile='orgm', items=items,
                       current=items[1]['path'], screen='HEADLESS-1', colors=dict(bg='#071422', accent='#71b7ff'))
        def open_wallpaper():
            p = subprocess.Popen(['python3','-c','import json,runpy,sys; m=runpy.run_path(sys.argv[1]); assert m["graphical_wallpaper_picker"](json.loads(sys.argv[2]))',str(binary/'orgm-sway'),json.dumps(catalog)],env=env,stdout=log,stderr=log,start_new_session=True)
            children.append(p)
            wait(lambda: (data := status()) and data['kind']=='wallpaper' and data['open'], 'resident wallpaper')
            time.sleep(.25)
            assert status()['pid'] == service_pid
            return p
        def wallpaper_status():
            return json.loads(command('qs','--path',str(ui/menu_entry),'ipc','call','wallpaper','status').stdout)
        failure.touch()
        process = open_wallpaper()
        assert wallpaper_status()['current'] == 1
        key('Return')
        wait(lambda: wallpaper_status()['error'] and not wallpaper_status()['busy'], 'resident wallpaper error')
        key('Escape')
        assert process.wait(timeout=5) == 0
        failure.unlink()
        process = open_wallpaper()
        assert wallpaper_status()['error'] == '', 'Old wallpaper errors must clear on reopening'
        key('Return')
        assert process.wait(timeout=5) == 0
        assert recorded()[-1] == ['wallpaper','wallpaper-set',items[1]['path']]
        before = recorded()
        process = open_wallpaper()
        key('Escape')
        assert process.wait(timeout=5) == 0 and recorded() == before
        video = home/'fixture-video.mp4'
        command('ffmpeg','-nostdin','-v','error','-f','lavfi','-i','color=c=purple:s=64x64:r=5','-t','0.4','-c:v','libx264','-pix_fmt','yuv420p',str(video)).check_returncode()
        catalog['items'] = [dict(path=str(video),url=video.as_uri(),name='fixture video',kind='video')]
        catalog['current'] = str(video)
        process = open_wallpaper()
        wait(lambda: wallpaper_status()['previews'][0]['ready'], 'resident video poster decoded')
        key('Escape')
        assert process.wait(timeout=5) == 0 and recorded() == before
        assert not status()['open'] and daemon.poll() is None
    launcher = subprocess.Popen([str(binary/'sway-app-launcher')], env=env, stdout=log, stderr=log, start_new_session=True)
    children.append(launcher)
    wait(lambda: any(s.get('namespace') == 'rofi' for o in json.loads(
         command('swaymsg', '-r', '-t', 'get_outputs').stdout) for s in o.get('layer_shell_surfaces', [])), 'Rofi launcher')
    time.sleep(.3)
    command('grim', str(home/'launcher.png')).check_returncode()
    key('Escape')
    assert launcher.wait(timeout=5) in (0, 1)
    # Profile changes retain Waybar/Caffeine, so its CSS watcher must survive
    # repeated atomic palette replacements, as performed by the real helper.
    bar_config = config/'waybar/config'
    bar_config.write_text(json.dumps(dict(name='menu-test-bar', position='top',
        height=30, modules_left=['clock'], reload_style_on_change=True)).replace('modules_left', 'modules-left'))
    bar_style = config/'waybar/style.css'
    bar_style.write_text('@import "orgm-current.css";\nwindow#waybar { background: @base; color: white; }\n')
    bar = subprocess.Popen(['waybar', '-c', str(bar_config), '-s', str(bar_style)],
                           env=env, stdout=log, stderr=log, start_new_session=True)
    children.append(bar)
    wait(lambda: bar_pixel() == (7, 20, 34), 'initial bar palette')
    for color, rgb in (('#123456', (18, 52, 86)), ('#654321', (101, 67, 33))):
        replacement = config/'waybar/new.css'
        replacement.write_text('@define-color base '+color+';\n')
        replacement.replace(config/'waybar/orgm-current.css')
        wait(lambda: bar_pixel() == rgb, 'bar palette refresh without restart')
        assert bar.poll() is None
    if resident_mode:
        process = start('power')
        before = recorded()
        key('5')
        key('Return')
        assert status()['confirming']
        daemon.terminate()
        daemon.wait(timeout=5)
        wait(lambda: any(s.get('namespace')=='rofi' for o in json.loads(command('swaymsg','-r','-t','get_outputs').stdout) for s in o.get('layer_shell_surfaces',[])), 'fallback after resident service exit')
        time.sleep(.25)  # Mapping precedes Rofi's keyboard-focus acknowledgement.
        key('Escape')
        assert process.wait(timeout=5)==0 and recorded()==before, 'Daemon exit cannot confirm a pending power action'
    log.flush()
    diagnostics = (home/'session.log').read_text()
    assert 'TypeError:' not in diagnostics and 'ReferenceError:' not in diagnostics, diagnostics
    print('PASS: power confirmation/cancel/suspend, saved profile previews/selection, active palette and real Rofi')
    print('Screenshots and isolated logs: '+str(home))
finally:
    for process in reversed(children):
        if process.poll() is None:
            os.killpg(process.pid, signal.SIGTERM)
            process.wait(timeout=5)
    if compositor.poll() is None:
        os.killpg(compositor.pid, signal.SIGTERM)
    compositor.wait(timeout=10)
    log.close()
