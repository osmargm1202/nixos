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

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = Path(os.environ['ORGM_TEST_QYLOCK_PACKAGE']).resolve()
META = json.loads((PACKAGE/'share/orgm-qylock/runtime.json').read_text())
PAM = Path(os.environ['ORGM_TEST_QYLOCK_PAM']).resolve()
HOME = Path(tempfile.mkdtemp(prefix='qylock-private-session-'))
runtime = HOME/'runtime'; runtime.mkdir(mode=0o700)
policy = HOME/'pam'; policy.mkdir()
for name in ('orgm-qylock-pw', 'orgm-qylock-fp'):
    (policy/name).write_text(f'auth required {PAM}\naccount required {PAM}\n')
(HOME/'sway.conf').write_text('output HEADLESS-1 mode 1920x1080 pos 0 0\nfont pango:monospace 10\ndefault_border none\n')
env = dict(os.environ, HOME=str(HOME), XDG_CONFIG_HOME=str(HOME/'.config'),
    XDG_STATE_HOME=str(HOME/'.local/state'), XDG_CACHE_HOME=str(HOME/'.cache'),
    XDG_DATA_HOME=str(HOME/'.local/share'), XDG_RUNTIME_DIR=str(runtime),
    WLR_BACKENDS='headless', WLR_HEADLESS_OUTPUTS='1', WLR_RENDERER='gles2',
    WLR_RENDERER_ALLOW_SOFTWARE='1', QT_QPA_PLATFORM='wayland',
    PULSE_SERVER='unix:'+str(runtime/'nonexistent-pulse'), QML_XHR_ALLOW_FILE_READ='1')
for key in ('DISPLAY','WAYLAND_DISPLAY','SWAYSOCK','DBUS_SESSION_BUS_ADDRESS','WAYLAND_SOCKET',
            'ORGM_VISUAL_PROFILE_STATE_DIR','QS_CONFIG_PATH','QS_CONFIG_NAME'):
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
    text = ipc(process, target, 'status')
    return json.loads(text) if text else None

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
    keeper = subprocess.Popen(['wtype','-s','240000'], env=env, stdout=log, stderr=log, start_new_session=True)
    children.append(keeper)
    time.sleep(.15)
    items = json.loads(Path(META['catalog']).read_text())
    def settings(item):
        return dict(id=item['id'], config=item['config'], themeUrl=(Path(META['themes'])/item['id']).as_uri(),
            pamDirectory=str(policy), user='qylock-private-test', realName='Private test', host='private-sway',
            home=str(HOME), icon='', fingerprint=False)
    candidates = [settings(i) for i in items]
    preview = launch(ROOT/'dotfiles/config/profiles/sway/.config/quickshell/orgm-lock/preview.qml', dict(candidates=candidates))
    wait(lambda:status(preview,'lock-preview'),'preview IPC')
    failed = []
    for item in items:
        ipc(preview,'lock-preview','load',item['id'])
        result = wait(lambda:(s if (s:=status(preview,'lock-preview')) and s['theme']==item['id'] and (s['ready'] or s['error']) else None), item['id'])
        if result['error']: failed.append(item['id'])
        elif item['id'] in ('winter','forest','clockwork/orbital'):
            time.sleep(.5)
            command('grim','-l','1','-o','HEADLESS-1',str(HOME/(item['id'].replace('/','-')+'.png'))).check_returncode()
    assert not failed, ('QML themes that did not load',failed)
    print(f'PASS: {len(items)} complete themes render with the local SDDM adapter, without Ryoku',flush=True)
    ipc(preview,'lock-preview','close')
    assert preview.wait(timeout=5)==0

    winter = next(i for i in items if i['id']=='winter')
    ready = HOME/'secure-ready'
    locker = launch(ROOT/'dotfiles/config/profiles/sway/.config/quickshell/orgm-lock/lock.qml',settings(winter),ready)
    wait(lambda:(s if (s:=status(locker,'orgm-lock')) and s['secure'] else None),'ext-session-lock secure')
    assert ready.read_text()=='secure'
    key('-k','Escape')
    assert status(locker,'orgm-lock')['secure'] and not status(locker,'orgm-lock')['authenticated']
    key('-k','F2')
    wait(lambda:status(locker,'orgm-lock')['fallback'],'fallback UI')
    key('incorrect-test-token')
    key('-k','Return')
    time.sleep(.4)
    assert status(locker,'orgm-lock')['secure'] and not status(locker,'orgm-lock')['authenticated']
    key('QYLOCK_TEST_ONLY_NOT_A_REAL_PASSWORD')
    key('-k','Return')
    assert locker.wait(timeout=5)==0
    print('PASS: real Wayland lock, Escape cannot unlock, fallback works, fake PAM rejects wrong token and unlocks only on success',flush=True)

    # Now validate the real launcher's daemonize/duplicate contract WITHOUT
    # starting any real PAM conversation (no typing into that lock).
    root = HOME/'.local/state/orgm-qylock-package'
    root.parent.mkdir(parents=True,exist_ok=True)
    root.symlink_to(PACKAGE)
    (HOME/'.config/qylock').mkdir(parents=True)
    (HOME/'.config/qylock/theme').write_text('winter\n')
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
