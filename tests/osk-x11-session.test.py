#!/usr/bin/env python3
"""Jarq path: private Xvfb+i3, actual OSK pointer clicks and Rofi selection."""
import glob,json,os,shutil,signal,subprocess,tempfile,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
XVFB=os.environ.get('ORGM_TEST_XVFB') or next(iter(glob.glob('/nix/store/*-xorg-server-*/bin/Xvfb')),None)
I3=os.environ.get('ORGM_TEST_I3') or str(Path.home()/'.local/state/orgm-osk-tools/i3-test/bin/i3')
XDOTOOL=os.environ.get('ORGM_TEST_XDOTOOL') or next(iter(glob.glob('/nix/store/*-xdotool-*/bin/xdotool')),None)
ENGINE=os.environ.get('ORGM_TEST_OSK_ENGINE') or str(Path.home()/'.local/state/orgm-osk-tools/engine/bin/orgm-osk-engine')
assert XVFB and XDOTOOL and Path(I3).exists() and Path(ENGINE).exists(),'supply cached Xvfb/i3/xdotool and built OSK engine'
with tempfile.TemporaryDirectory(prefix='ox-') as tmp:
    home=Path(tmp);runtime=home/'r';runtime.mkdir(mode=0o700)
    ui=home/'ui';shutil.copytree(ROOT/'dotfiles/config/programs/shell/.config/quickshell/orgm-osk',ui)
    config=home/'i3.conf';config.write_text('font pango:monospace 10\nfocus_follows_mouse no\nfor_window [class="(?i)rofi"] floating enable, move position center\n')
    subprocess.run(['orgm-dot','--repo',str(ROOT),'--home',tmp,'--profile','i3','--user','jarq','--host','jarq','pull','rofi'],check=True,capture_output=True)
    env=dict(os.environ,HOME=tmp,XDG_CONFIG_HOME=tmp+'/.config',XDG_DATA_HOME=tmp+'/.data',XDG_CACHE_HOME=tmp+'/.cache',XDG_STATE_HOME=tmp+'/.state',XDG_RUNTIME_DIR=str(runtime),DBUS_SESSION_BUS_ADDRESS='unix:path='+tmp+'/no-bus',QT_QPA_PLATFORM='xcb',ORGM_OSK_BACKEND='x11',ORGM_OSK_ENGINE=ENGINE)
    for key in ('DISPLAY','WAYLAND_DISPLAY','WAYLAND_SOCKET','SWAYSOCK','HYPRLAND_INSTANCE_SIGNATURE','QS_CONFIG_PATH','QS_CONFIG_NAME'):env.pop(key,None)
    log=(home/'session.log').open('w');processes=[]
    def start(*args,**kwargs):
        p=subprocess.Popen(args,env=env,stderr=log,start_new_session=True,**kwargs);processes.append(p);return p
    def cmd(*args):return subprocess.check_output(args,env=env,text=True,timeout=6)
    def wait(probe,label):
        end=time.monotonic()+10
        while time.monotonic()<end:
            try:
                value=probe()
                if value:return value
            except (subprocess.SubprocessError,json.JSONDecodeError):pass
            time.sleep(.06)
        raise AssertionError('Timeout: '+label)
    def status():return json.loads(cmd('qs','--path',str(ui/'shell.qml'),'ipc','call','osk','status'))
    def panel():return status()['panels'][0]
    def click(rect):
        cmd(XDOTOOL,'mousemove',str(round(rect['x']+rect['width']/2)),str(round(rect['y']+rect['height']/2)),'click','1');time.sleep(.1)
    try:
        server=start(XVFB,'-displayfd','1','-screen','0','1280x800x24','-nolisten','tcp','-noreset','-ac',stdout=subprocess.PIPE,text=True)
        display=server.stdout.readline().strip();assert display.isdigit();env['DISPLAY']=':'+display
        cmd(os.environ.get('ORGM_TEST_SETXKBMAP') or shutil.which('setxkbmap') or next(iter(glob.glob('/nix/store/*-setxkbmap-*/bin/setxkbmap'))),'-layout','us,latam','-variant','altgr-intl,','-option','grp:ctrl_space_toggle')
        start(I3,'-c',str(config),stdout=log);time.sleep(.3)
        start('qs','--no-duplicate','--path',str(ui/'shell.qml'),stdout=log)
        wait(lambda:status().get('ready'),'X11 QS and input engine')
        assert panel()['button'].get('visible',True),'X11 controls must remain visible without WAYLAND_DISPLAY'
        click(panel()['button']);wait(lambda:status()['open'],'X11 fixed button without Rofi')
        cmd('qs','--path',str(ui/'shell.qml'),'ipc','call','osk','hide')
        for word,codes in [('mañana',[50,30,39,30,49,30]),('café',[46,30,33,26,18]),('Ñ@',['shift',39,'altgr',3,'altgr']),('a b',[30,57,16,14,48]),('a@',['altgr',30,3,'altgr']),('€{',['altgr','shift',18,8,'altgr']),('b',[30,30,30,30,30,30,'hold-backspace',48]),('',[1])]:
            rofi=start(str(ROOT/'dotfiles/config/profiles/i3/.local/bin/i3-rofi'),'Prueba OSK','4',stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True)
            rofi.stdin.write('different decoy\n');rofi.stdin.close();time.sleep(.35)
            assert rofi.poll() is None
            click(panel()['button']);wait(lambda:status()['open'],'fixed button while Rofi open')
            assert rofi.poll() is None,'OSK must not dismiss X11 Rofi'
            for code in codes+[28]:
                data=panel();target=14 if code=='hold-backspace' else code
                key=next(k for k in data['keys'] if (k['kind']==target if isinstance(target,str) else k['code']==target));origin=data['keyboard']
                rect=dict(key,x=key['x']+origin['x'],y=key['y']+origin['y'])
                if code=='hold-backspace':
                    cmd(XDOTOOL,'mousemove',str(round(rect['x']+rect['width']/2)),str(round(rect['y']+rect['height']/2)),'mousedown','1')
                    time.sleep(1.4);cmd(XDOTOOL,'mouseup','1');time.sleep(.2)
                else:click(rect)
            wait(lambda:rofi.poll() is not None,'X11 Rofi accepts OSK typing')
            actual=rofi.stdout.read().strip();assert actual==word,(word,actual)
            print('PASS: Jarq i3/X11 actual OSK button and '+word+' Rofi selection',flush=True)
            cmd('qs','--path',str(ui/'shell.qml'),'ipc','call','osk','hide');wait(lambda:not status()['open'],'hide')
        assert not status()['error'],status()['error']
    except Exception:
        log.flush();print((home/'session.log').read_text(errors='replace')[-4500:]);raise
    finally:
        for p in reversed(processes):
            if p.poll() is None:os.killpg(p.pid,signal.SIGTERM)
            try:p.wait(timeout=3)
            except subprocess.TimeoutExpired:os.killpg(p.pid,signal.SIGKILL);p.wait()
        log.close()
