#!/usr/bin/env python3
"""Actual OSK button/key clicks into Rofi, private headless Sway and state only."""
import glob,json,os,shutil,signal,subprocess,tempfile,time
from pathlib import Path
from helpers.wayland_pointer import Pointer
ROOT=Path(__file__).resolve().parents[1]
SWAY=os.environ.get('ORGM_TEST_SWAY') or shutil.which('sway') or next(iter(glob.glob('/nix/store/*-swayfx-0.5.3/bin/sway')),None)
ENGINE=os.environ.get('ORGM_TEST_OSK_ENGINE') or str(Path.home()/'.local/state/orgm-osk-tools/engine/bin/orgm-osk-engine')
assert SWAY and Path(ENGINE).exists(),'supply real Sway and built OSK engine'
with tempfile.TemporaryDirectory(prefix='ok-') as tmp:
    home=Path(tmp);runtime=home/'r';runtime.mkdir(mode=0o700)
    ui=home/'ui';shutil.copytree(ROOT/'dotfiles/config/programs/shell/.config/quickshell/orgm-osk',ui)
    shutil.copytree(ROOT/'dotfiles/config/profiles/sway/.config/rofi-sway',home/'.config/rofi-sway')
    config=home/'sway.conf';config.write_text('output HEADLESS-1 mode 1280x800\nfont pango:monospace 10\nxwayland disable\nseat * hide_cursor 0\n')
    env=dict(os.environ,HOME=tmp,XDG_CONFIG_HOME=tmp+'/.config',XDG_DATA_HOME=tmp+'/.data',XDG_CACHE_HOME=tmp+'/.cache',XDG_STATE_HOME=tmp+'/.state',XDG_RUNTIME_DIR=str(runtime),DBUS_SESSION_BUS_ADDRESS='unix:path='+tmp+'/no-bus',WLR_BACKENDS='headless',WLR_RENDERER='pixman',WLR_LIBINPUT_NO_DEVICES='1',QT_QPA_PLATFORM='wayland',ORGM_OSK_ENGINE=ENGINE)
    for name in ('DISPLAY','WAYLAND_DISPLAY','SWAYSOCK','HYPRLAND_INSTANCE_SIGNATURE','WAYLAND_SOCKET','QS_CONFIG_PATH','QS_CONFIG_NAME'):env.pop(name,None)
    processes=[];pointer=None;log=(home/'session.log').open('w')
    def start(*args,**kwargs):
        p=subprocess.Popen(args,env=env,stderr=log,start_new_session=True,**kwargs);processes.append(p);return p
    def cmd(*args):return subprocess.check_output(args,env=env,text=True,timeout=6)
    def wait(probe,label):
        deadline=time.monotonic()+10
        while time.monotonic()<deadline:
            try:
                value=probe()
                if value:return value
            except (subprocess.SubprocessError,json.JSONDecodeError):pass
            time.sleep(.06)
        raise AssertionError('Timeout: '+label)
    def status():return json.loads(cmd('qs','--path',str(ui/'shell.qml'),'ipc','call','--','osk','status'))
    def panel():return status()['panels'][0]
    def click(rect):
        pointer.move(rect['x']+rect['width']/2,rect['y']+rect['height']/2,1280,800)
        pointer.button(True);pointer.button(False);time.sleep(.08)
    try:
        compositor=start(SWAY,'--unsupported-gpu','-c',str(config),stdout=log)
        display=wait(lambda:next((p for p in runtime.glob('wayland-*') if p.is_socket()),None),'headless Wayland')
        env['WAYLAND_DISPLAY']=display.name
        env['SWAYSOCK']=str(wait(lambda:next(runtime.glob('sway-ipc.*.sock'),None),'Sway IPC'))
        shell=start('qs','--no-duplicate','--path',str(ui/'shell.qml'),stdout=log)
        wait(lambda:status().get('ready'),'QS and persistent native engine')
        assert not panel()['button'].get('visible',True),'fixed OSK button must be hidden outside tablet mode'
        assert not panel().get('gesture',{'visible':True})['visible'],'no touch handle outside tablet mode'
        # Desktop commands can still open the keyboard without making touch controls visible.
        cmd('qs','--path',str(ui/'shell.qml'),'ipc','call','--','osk','show')
        wait(lambda:status()['open'],'manual OSK IPC opens in desktop mode')
        assert not panel()['button']['visible']
        cmd('qs','--path',str(ui/'shell.qml'),'ipc','call','--','osk','hide')
        helper=str(ROOT/'dotfiles/config/profiles/wayland/.local/bin/orgm-rofi')
        pref=home/'.state/orgm-tablet/preferences.json';pref.parent.mkdir(parents=True,exist_ok=True);pref.write_text('{"mode":"on"}')
        dump=cmd(helper,'--compositor','sway','-dump-theme')
        import re
        for selector in (r'\*',r'prompt'):
            assert re.search(selector+r'\s*\{[^}]*font:\s*"JetBrainsMono Nerd Font 18"',dump,re.S),'effective tablet font override '+selector
        wait(lambda:panel()['button']['visible'] and panel()['gesture']['visible'],'tablet controls appear after first preference creation')
        # Real policy writes use atomic replacement, not in-place edits.
        def policy(contents):
            temporary=pref.with_suffix('.tmp');temporary.write_text(contents);temporary.replace(pref)
        for contents in ('{"mode":"off"}','{"mode":"auto"}','bad-json','{"mode":true}'):
            policy(contents)
            wait(lambda:not panel()['button']['visible'] and not panel()['gesture']['visible'],'invalid/off/old-auto policy hides controls')
            policy('{"mode":"on"}')
            wait(lambda:panel()['button']['visible'],'atomic tablet-on update')
        pref.unlink()
        wait(lambda:not panel()['button']['visible'],'deleted policy hides controls')
        policy('{"mode":"on"}')
        wait(lambda:panel()['button']['visible'],'recreated policy restores controls without shell restart')
        cmd('qs','--path',str(ui/'shell.qml'),'ipc','call','--','osk','show')
        policy('{"mode":"off"}')
        wait(lambda:not panel()['button']['visible'] and status()['open'],'leaving tablet mode hides button without closing manual keyboard')
        cmd('qs','--path',str(ui/'shell.qml'),'ipc','call','--','osk','hide')
        policy('{"mode":"on"}')
        wait(lambda:panel()['button']['visible'],'tablet controls restored for input fixtures')
        print('PASS: tablet-only OSK controls follow missing/off/on/auto/corrupt/deleted/atomic policies; desktop IPC remains usable',flush=True)
        print('PASS: actual Rofi parsed tablet theme uses18px globally and in prompt',flush=True)
        pointer=Pointer(display)
        for word,codes in [('mañana',[50,30,39,30,49,30]),('café',[46,30,33,26,18]),('Ñ@',['shift',39,'altgr',3,'altgr']),('a b',[30,57,16,14,48]),('a@',['altgr',30,3,'altgr']),('€{',['altgr','shift',18,8,'altgr']),('b',[30,30,30,30,30,30,'hold-backspace',48]),('',[1])]:
            rofi=start(str(ROOT/'dotfiles/config/profiles/wayland/.local/bin/orgm-rofi'),'--compositor','sway','-dmenu','-p','Prueba OSK','-lines','4',stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True)
            rofi.stdin.write('different decoy\n');rofi.stdin.close()
            time.sleep(.35)
            assert rofi.poll() is None,'Rofi must remain available before opening OSK'
            click(panel()['button'])
            wait(lambda:status()['open'],'actual fixed-button click opens keyboard')
            assert rofi.poll() is None,'opening OSK must not dismiss Rofi'
            for code in codes+[28]:
                state=panel();target=14 if code=='hold-backspace' else code
                k=next(k for k in state['keys'] if (k['kind']==target if isinstance(target,str) else k['code']==target))
                origin=state['keyboard'];rect=dict(k,x=k['x']+origin['x'],y=k['y']+origin['y'])
                if code=='hold-backspace':
                    pointer.move(rect['x']+rect['width']/2,rect['y']+rect['height']/2,1280,800)
                    pointer.button(True);time.sleep(1.4);pointer.button(False);time.sleep(.2)
                else:click(rect)
            wait(lambda:rofi.poll() is not None,'Rofi selection with actual OSK taps')
            selected=rofi.stdout.read().strip();assert selected==word,(word,selected)
            print('PASS: fixed OSK button, actual taps type/select '+word+' in Rofi without focus loss',flush=True)
            cmd('qs','--path',str(ui/'shell.qml'),'ipc','call','--','osk','hide')
            wait(lambda:not status()['open'],'hide keyboard')
        pointer.move(640,795,1280,800);pointer.button(True);pointer.move(640,700,1280,800);pointer.button(False)
        wait(lambda:status()['open'],'bottom edge swipe opens keyboard')
        if os.environ.get('ORGM_TEST_OSK_SCREENSHOT'):
            cmd('grim',os.environ['ORGM_TEST_OSK_SCREENSHOT'])
        before=panel()['keyboard']
        click(dict(x=before['x']+before['width']-108,y=before['y'],width=1,height=34))
        wait(lambda:panel()['keyboard']['height']>before['height'],'actual plus resizes keyboard')
        click(panel()['button'])
        wait(lambda:not status()['open'],'raised fixed button also closes keyboard')
        print('PASS: actual bottom gesture opens keyboard',flush=True)
        assert not status()['error'],status()['error']
        child_ids=Path(f'/proc/{shell.pid}/task/{shell.pid}/children').read_text().split()
        assert len(child_ids)==1,child_ids
        os.kill(int(child_ids[0]),signal.SIGTERM)
        wait(lambda:not status()['ready'],'engine disconnect visible')
        cmd('qs','--path',str(ui/'shell.qml'),'ipc','call','--','osk','retry')
        wait(lambda:status()['ready'] and not status()['error'],'manual engine retry')
        print('PASS: disconnected engine can retry without restarting shell',flush=True)
    except Exception:
        log.flush();print((home/'session.log').read_text(errors='replace')[-5000:]);raise
    finally:
        if pointer:pointer.close()
        for p in reversed(processes):
            if p.poll() is None:os.killpg(p.pid,signal.SIGTERM)
            try:p.wait(timeout=3)
            except subprocess.TimeoutExpired:os.killpg(p.pid,signal.SIGKILL);p.wait()
        log.close()
