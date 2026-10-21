#!/usr/bin/env python3
"""Opt-in qylock render/protocol/PAM test; private HOME, Wayland and D-Bus only.

ORGM_TEST_QYLOCK_PACKAGE=/nix/store/... ORGM_TEST_QYLOCK_PAM=/nix/store/.../lib/qylock-test-pam.so
No real password is supplied, no production PAM policy is invoked, no sensor.
"""
import json
import os
from pathlib import Path
import pwd
import shutil
import signal
import subprocess
import tempfile
import time
from helpers.wayland_pointer import Pointer

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = Path(os.environ['ORGM_TEST_QYLOCK_PACKAGE']).resolve()
META = json.loads((PACKAGE/'share/orgm-qylock/runtime.json').read_text())
PAM = Path(os.environ['ORGM_TEST_QYLOCK_PAM']).resolve()
HOME = Path(tempfile.mkdtemp(prefix='qylock-private-session-'))
runtime = HOME/'runtime'; runtime.mkdir(mode=0o700)
policy = HOME/'pam'; policy.mkdir()
for name in ('orgm-qylock-pw', 'orgm-qylock-fp'):
    (policy/name).write_text(f'auth required {PAM}\naccount required {PAM}\n')
(HOME/'sway.conf').write_text('output HEADLESS-1 mode 1920x1080 pos 0 0\noutput HEADLESS-2 mode 1280x720 pos 1920 0\nfont pango:monospace 10\ndefault_border none\n')
env = dict(os.environ, HOME=str(HOME), XDG_CONFIG_HOME=str(HOME/'.config'),
    XDG_STATE_HOME=str(HOME/'.local/state'), XDG_CACHE_HOME=str(HOME/'.cache'),
    XDG_DATA_HOME=str(HOME/'.local/share'), XDG_RUNTIME_DIR=str(runtime),
    XDG_CURRENT_DESKTOP='sway', WLR_BACKENDS='headless', WLR_HEADLESS_OUTPUTS='2', WLR_RENDERER='gles2',
    WLR_RENDERER_ALLOW_SOFTWARE='1', QT_QPA_PLATFORM='wayland',
    PULSE_SERVER='unix:'+str(runtime/'nonexistent-pulse'), QML_XHR_ALLOW_FILE_READ='1',
    DBUS_SYSTEM_BUS_ADDRESS='unix:path='+str(runtime/'nonexistent-system-bus'))
for key in ('DISPLAY','WAYLAND_DISPLAY','SWAYSOCK','DBUS_SESSION_BUS_ADDRESS','WAYLAND_SOCKET',
            'ORGM_VISUAL_PROFILE_STATE_DIR','QS_CONFIG_PATH','QS_CONFIG_NAME','HYPRLAND_INSTANCE_SIGNATURE'):
    env.pop(key, None)
intel = Path('/dev/dri/by-path/pci-0000:00:02.0-render')
if intel.exists(): env['WLR_RENDER_DRM_DEVICE'] = str(intel.resolve())
log = (HOME/'session.log').open('w')
sway = subprocess.Popen(['dbus-run-session','--','sh','-c',
    'printf "%s" "$DBUS_SESSION_BUS_ADDRESS" > "$1";shift;exec "$@"', '_', str(HOME/'bus'),
    shutil.which('sway'), '-c', str(HOME/'sway.conf')], env=env, cwd=HOME,
    stdout=log, stderr=log, start_new_session=True)
children = []

def wait(probe, why, timeout=8):
    deadline = time.monotonic()+timeout
    while time.monotonic() < deadline:
        value = probe()
        if value: return value
        assert sway.poll() is None, 'Private Sway exited'
        time.sleep(.05)
    raise AssertionError('Timeout: '+why+'; logs '+str(HOME))

def command(*args):
    return subprocess.run(args, env=env, capture_output=True, text=True, timeout=20)

def ipc(process, target, method, *args):
    result = command(META['qs'], 'ipc', '--pid', str(process.pid), 'call', target, method, *args)
    return result.stdout.strip() if result.returncode == 0 else ''

def status(process, target):
    assert process.poll() is None, f'{target} exited unexpectedly; logs {HOME}'
    text = ipc(process, target, 'status')
    try:
        return json.loads(text) if text else None
    except ValueError:
        return None

def launch(qml, data, ready=None):
    path = HOME/(f'data-{len(children)}.json')
    path.write_text(json.dumps(data))
    local = dict(env, ORGM_LOCK_DATA=str(path))
    if ready: local['ORGM_LOCK_READY'] = str(ready)
    process = subprocess.Popen([META['qs'], '--path', str(qml)], env=local, cwd=HOME,
        stdout=log, stderr=log, start_new_session=True)
    children.append(process)
    return process

def key(*args):
    command('wtype', *args).check_returncode()
    time.sleep(.2)

try:
    env['SWAYSOCK'] = str(wait(lambda:next(iter(runtime.glob('sway-ipc.*.sock')),None),'IPC'))
    env['DBUS_SESSION_BUS_ADDRESS'] = (HOME/'bus').read_text()
    env['WAYLAND_DISPLAY'] = wait(lambda:next((p.name for p in runtime.glob('wayland-*') if not p.name.endswith('.lock')),None),'Wayland')
    assert str(runtime) in env['SWAYSOCK']
    command('swaymsg','focus','output','HEADLESS-1').check_returncode()
    keeper = subprocess.Popen(['wtype','-s','240000'], env=env, stdout=log, stderr=log, start_new_session=True)
    children.append(keeper)
    time.sleep(.15)
    items = json.loads(Path(META['catalog']).read_text())
    def settings(item):
        return dict(id=item['id'], config=item['config'], themeUrl=(Path(META['themes'])/item['id']).as_uri(),
            pamDirectory=str(policy), user=pwd.getpwuid(os.getuid()).pw_name, realName='Private test', host='private-sway',
            home=str(HOME), icon='', fingerprint=False)
    def touch_test():
        # Keys-only theme: touch the actual packaged auth keyboard, then its Enter.
        # Only the fake test PAM token is used on this private display.
        pixel=next(i for i in items if i['id']=='pixel-coffee')
        command('swaymsg','output','HEADLESS-2','disable').check_returncode()
        touched=launch(Path(META['lockQml']),settings(pixel),HOME/'touch-ready')
        wait(lambda:(s if (s:=status(touched,'orgm-lock')) and s['secure'] and s['surfaces']==1 else None),'pixel touch lock')
        command('swaymsg','focus','output','HEADLESS-1').check_returncode();time.sleep(.7)
        key('QYLOCK_TEST_ONLY_NOT_A_REAL_PASSWORD')
        pointer=Pointer(runtime/env['WAYLAND_DISPLAY'])
        try:
            def tap_at(x,y):
                pointer.move(x,y,1920,1080);time.sleep(.1);pointer.button(True);pointer.button(False);time.sleep(.25)
            tap_at(94,1042)  # visible secure keyboard button, output1
            if os.environ.get('ORGM_TEST_QYLOCK_TOUCH_CAPTURE'):command('grim',os.environ['ORGM_TEST_QYLOCK_TOUCH_CAPTURE']).check_returncode()
            tap_at(1446,850) # Enter, common14.9-unit second row,1100x360 board
            try:assert touched.wait(timeout=7)==0
            except subprocess.TimeoutExpired:raise AssertionError('Touch Enter did not submit: '+str(status(touched,'orgm-lock')))
        finally:pointer.close()
        command('swaymsg','output','HEADLESS-2','enable').check_returncode()
        print('PASS: actual secure-lock keyboard button + touch Enter submits Keys-only Pixel Coffee through fake PAM',flush=True)

    if os.environ.get('ORGM_TEST_QYLOCK_TOUCH_ONLY'):
        touch_test();raise SystemExit(0)
    candidates = [settings(i) for i in items]
    preview = launch(ROOT/'dotfiles/config/profiles/sway/.config/quickshell/orgm-lock/preview.qml', dict(candidates=candidates))
    wait(lambda:status(preview,'lock-preview'),'preview IPC')
    failed = []
    rendering = [] if os.environ.get('ORGM_TEST_QYLOCK_SKIP_CATALOG') else items
    for item in rendering:
        ipc(preview,'lock-preview','load',item['id'])
        result = wait(lambda:(s if (s:=status(preview,'lock-preview')) and s['theme']==item['id'] and (s['ready'] or s['error']) else None), item['id'])
        if result['error']: failed.append(item['id'])
        elif item['id'] in ('winter','forest','clockwork/orbital'):
            time.sleep(.5)
            command('grim','-l','1','-o','HEADLESS-1',str(HOME/(item['id'].replace('/','-')+'.png'))).check_returncode()
    assert not failed, ('QML themes that did not load',failed)
    print(f'PASS: {len(rendering)} theme rendering cases (debug skip={not bool(rendering)}), without Ryoku',flush=True)
    ipc(preview,'lock-preview','close')
    assert preview.wait(timeout=5)==0

    # Real SDDM greeter, TEST MODE only: no daemon, login/PAM, root operation
    # or physical device. Its compiled-in components differ from our shim.
    greeter_themes=('winter','forest','clockwork/orbital')
    for slug in greeter_themes:
        output=HOME/('sddm-'+slug.replace('/','-')+'.log')
        with output.open('w') as stream:
            process=subprocess.Popen([META['greeter'],'--test-mode','--theme',str(Path(META['themes'])/slug)],
                env=dict(env,**META['greeterEnvironment']),cwd=HOME,stdout=stream,stderr=stream,start_new_session=True)
            children.append(process)
            def mapped():
                assert process.poll() is None, 'Test greeter exited: '+output.read_text()
                tree=json.loads(command('swaymsg','-r','-t','get_tree').stdout)
                def find(node):
                    return node.get('pid')==process.pid or any(find(child) for key in ('nodes','floating_nodes') for child in node.get(key,[]))
                return find(tree)
            wait(mapped,'real SDDM test-mode '+slug)
            time.sleep(.6)
            text=output.read_text()
            assert 'is not installed' not in text and 'is not a type' not in text,text
            process.terminate();process.wait(timeout=5)
    print('PASS: Winter, Forest and Clockwork load in the actual SDDM greeter test-mode, without restarting SDDM or invoking login',flush=True)

    # The chooser must unmap/release its exclusive keyboard while Polkit
    # authenticates. Exercise a cancelled prompt, restored focus and retry.
    backend = HOME/'fake-select'
    backend.write_text('#!'+shutil.which('python3')+'\nimport pathlib,sys,time\np=pathlib.Path(__file__).parent\n'
        '(p/"select-called").write_text(repr(sys.argv[1:]))\n'
        'time.sleep(2)\n'
        'if not (p/"select-success").exists():\n print("Autorización de prueba cancelada",file=sys.stderr);sys.exit(126)\n')
    backend.chmod(0o700)
    chooser_data = HOME/'themes.json'
    chooser_data.write_text(json.dumps(dict(current='winter', screen='HEADLESS-1', profile='qylock',
        backend=str(backend), colors=dict(bg='#101020',surface='#222234',fg='#eeeeff',muted='#8899aa',accent='#88aaff',error='#ff8888'),
        items=[dict(id=i['id'],path=i['id'],name=i['name'],url=(Path(META['previews'])/i['preview']).as_uri()) for i in items])))
    def chooser():
        process = subprocess.Popen([META['qs'],'--path',str(ROOT/'dotfiles/config/profiles/sway/.config/quickshell/orgm-locks')],
            env=dict(env,ORGM_WALLPAPER_DATA=str(chooser_data),ORGM_WALLPAPER_STATUS=str(HOME/'chooser-ready')),
            cwd=HOME,stdout=log,stderr=log,start_new_session=True)
        children.append(process)
        wait(lambda:status(process,'lock-themes'),'theme chooser')
        wait(lambda:layer_visible(),'chooser keyboard surface')
        time.sleep(.15)
        return process
    def layer_visible():
        outputs=json.loads(command('swaymsg','-r','-t','get_outputs').stdout)
        return any(l['namespace']=='orgm-lock-themes' for o in outputs for l in o.get('layer_shell_surfaces',[]))
    prompt=launch(ROOT/'tests/helpers/qylock-prompt.qml',{})
    wait(lambda:ipc(prompt,'private-prompt','text')=='','prompt IPC')
    first=chooser()
    assert status(first,'lock-themes')['selected']=='winter'
    key('-k','Escape')
    assert first.wait(timeout=5)==0 and not (HOME/'select-called').exists()
    second=chooser()
    key('-k','Right'); selected=status(second,'lock-themes')['selected']
    key('-k','Return')
    wait(lambda:status(second,'lock-themes')['busy'],'authorization wait')
    wait(lambda:not layer_visible(),'chooser hidden during authorization')
    key('private-agent-can-type')
    assert ipc(prompt,'private-prompt','text')=='private-agent-can-type'
    wait(lambda:(s if (s:=status(second,'lock-themes')) and not s['busy'] and s['error'] else None),'cancel restores chooser')
    assert status(second,'lock-themes')['selected']==selected
    before=status(second,'lock-themes')['current']
    key('-k','Left')
    assert status(second,'lock-themes')['current']==before-1
    (HOME/'select-success').touch()
    key('-k','Return')
    assert second.wait(timeout=5)==0
    ipc(prompt,'private-prompt','close');prompt.wait(timeout=5)
    print('PASS: 41-theme carousel, Escape cancellation, authentication prompt uncovered/typeable, cancelled selection retained, focus restored and retry exits',flush=True)

    winter = next(i for i in items if i['id']=='winter')
    ready = HOME/'secure-ready'
    locker = launch(Path(META['lockQml']),settings(winter),ready)
    wait(lambda:(s if (s:=status(locker,'orgm-lock')) and s['secure'] and s['surfaces']==2 else None),'ext-session-lock secure on both monitors')
    assert ready.read_text()=='secure'
    command('swaymsg','output','HEADLESS-2','disable').check_returncode()
    wait(lambda:(s if (s:=status(locker,'orgm-lock')) and s['secure'] and s['surfaces']==1 else None),'disabled test monitor')
    command('swaymsg','output','HEADLESS-2','enable').check_returncode()
    wait(lambda:(s if (s:=status(locker,'orgm-lock')) and s['secure'] and s['surfaces']==2 else None),'hotplug while securely locked')
    for mode in ('1280x720','1920x1080'):
        command('swaymsg','output','HEADLESS-1','mode',mode).check_returncode()
        time.sleep(.3)
        assert status(locker,'orgm-lock')['secure']
    for scale in ('1.25','1'):
        command('swaymsg','output','HEADLESS-1','scale',scale).check_returncode()
        time.sleep(.3)
        assert status(locker,'orgm-lock')['secure']
    for output in ('HEADLESS-2','HEADLESS-1'):
        command('swaymsg','output',output,'disable').check_returncode()
    wait(lambda:(s if (s:=status(locker,'orgm-lock')) and s['secure'] and s['surfaces']==0 else None),'all monitors off, secure lock survives placeholder screen')
    for output in ('HEADLESS-1','HEADLESS-2'):
        command('swaymsg','output',output,'enable').check_returncode()
    wait(lambda:(s if (s:=status(locker,'orgm-lock')) and s['secure'] and s['surfaces']==2 else None),'all monitors restored while locked')
    command('swaymsg','focus','output','HEADLESS-1').check_returncode()
    key('-k','Escape')
    assert status(locker,'orgm-lock')['secure'] and not status(locker,'orgm-lock')['authenticated']
    key('-k','F2')
    wait(lambda:status(locker,'orgm-lock')['fallback'],'fallback UI')
    key('incorrect-test-token')
    key('-k','Return')
    try:
        wait(lambda:(s if (s:=status(locker,'orgm-lock')) and not s['submitting'] else None),'fake PAM rejection')
    except AssertionError:
        raise AssertionError('Fake PAM rejection stalled: '+str(status(locker,'orgm-lock')))
    assert status(locker,'orgm-lock')['secure'] and not status(locker,'orgm-lock')['authenticated']
    key('QYLOCK_TEST_ONLY_NOT_A_REAL_PASSWORD')
    key('-k','Return')
    try:
        assert locker.wait(timeout=5)==0
    except subprocess.TimeoutExpired:
        raise AssertionError('Fake PAM did not unlock: '+str(status(locker,'orgm-lock')))
    print('PASS: two-monitor Wayland lock, hotplug/all-off/restore, mode/scale changes, Escape rejection, fallback and fake-PAM negative/positive authentication',flush=True)

    themed=launch(Path(META['lockQml']),settings(winter),HOME/'theme-ready')
    wait(lambda:(s if (s:=status(themed,'orgm-lock')) and s['secure'] else None),'winter real lock')
    time.sleep(.6)
    key('QYLOCK_TEST_ONLY_NOT_A_REAL_PASSWORD');key('-k','Return')
    assert themed.wait(timeout=5)==0
    print('PASS: normal Winter theme submits through the same real PAM adapter (test token only)',flush=True)

    touch_test()

    # Now validate the real launcher's daemonize/duplicate contract WITHOUT
    # starting any real PAM conversation (no typing into that lock).
    root = HOME/'.local/state/orgm-qylock-package'
    root.parent.mkdir(parents=True,exist_ok=True)
    root.symlink_to(PACKAGE)
    (HOME/'.config/qylock').mkdir(parents=True)
    (HOME/'.config/qylock/theme').write_text('winter\n')
    (HOME/'.config/orgm-qylock').mkdir()
    (HOME/'.config/orgm-qylock/fingerprint').write_text('off\n')
    helper = ROOT/'dotfiles/config/profiles/sway/.local/bin/orgm-qylock'
    started = command(str(helper),'lock')
    assert started.returncode==0,started.stderr
    information = next(p for p in runtime.glob('orgm-qylock-*.json'))
    info = json.loads(information.read_text())
    # The detached supervisor has its own process group, tracked for cleanup.
    supervisor_pid = info.get('supervisor')
    if supervisor_pid: children.append(supervisor_pid)
    duplicate = command(str(helper),'lock')
    assert duplicate.returncode==0,duplicate.stderr
    result=command(META['qs'],'ipc','--pid',str(info['pid']),'call','orgm-lock','status')
    assert json.loads(result.stdout)['secure']
    print('PASS: production launcher returns only after secure; duplicate request confirms existing real lock; no real PAM/sensor invoked',flush=True)
finally:
    # Destroy the private compositor before killing any remaining lock client.
    processes=[sway]+children
    for process in processes:
        pid = process if isinstance(process,int) else process.pid
        try: os.killpg(pid,signal.SIGTERM)
        except ProcessLookupError: pass
    for process in processes:
        if isinstance(process,int): continue
        try: process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid,signal.SIGKILL);process.wait(timeout=3)
    log.close()
    print('Private logs/previews:',HOME,flush=True)
