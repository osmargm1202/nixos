#!/usr/bin/env python3
"""Private Sway + real WayVNC: frames/input, video survives viewer disconnect.

No parent display/socket/input is used; no real user content is captured.
"""
import json
import os
from pathlib import Path
import shutil
import signal
import socket
import subprocess
import sys
import tempfile
import time
sys.dont_write_bytecode=True
sys.path.insert(0,str(Path(__file__).parent/'helpers'))
from rfb import Client
ROOT=Path(__file__).resolve().parents[1]
SWAY=shutil.which('sway')
if not SWAY or any(not shutil.which(tool) for tool in ('wayvnc','mpv','wl-copy','ffmpeg')):
    print('SKIP: explicit private Sway/WayVNC/mpv/wl-copy/ffmpeg test tools unavailable')
    raise SystemExit(0)
root=Path(tempfile.mkdtemp(prefix='remote-desktop-fixture-'))
runtime=root/'runtime';runtime.mkdir(mode=0o700)
(root/'sway.conf').write_text('xwayland disable\noutput * mode 640x360\nseat seat0 fallback true\nfocus_follows_mouse no\n')
env=dict(os.environ,HOME=str(root),XDG_RUNTIME_DIR=str(runtime),XDG_CONFIG_HOME=str(root/'config'),XDG_DATA_HOME=str(root/'data'),XDG_CACHE_HOME=str(root/'cache'),XDG_STATE_HOME=str(root/'state'),WLR_BACKENDS='headless',WLR_RENDERER='pixman',WLR_LIBINPUT_NO_DEVICES='1')
for key in ('DISPLAY','WAYLAND_DISPLAY','SWAYSOCK','I3SOCK','HYPRLAND_INSTANCE_SIGNATURE','DBUS_SESSION_BUS_ADDRESS'):
    env.pop(key,None)
log=(root/'fixture.log').open('w')
children=[]
def start(args,environment=env):
    child=subprocess.Popen(args,env=environment,stdout=log,stderr=log,start_new_session=True)
    children.append(child);return child
def wait(probe,label,timeout=15):
    deadline=time.monotonic()+timeout
    while time.monotonic()<deadline:
        result=probe()
        if result:return result
        if children and children[0].poll() is not None:raise AssertionError('private Sway exited; '+str(root))
        time.sleep(.05)
    raise AssertionError(label+' timed out; logs '+str(root))
def mpv(property):
    with socket.socket(socket.AF_UNIX) as client:
        client.settimeout(2);client.connect(str(root/'mpv.sock'))
        client.sendall((json.dumps({'command':['get_property',property],'request_id':1})+'\n').encode())
        stream=client.makefile('rb')
        for line in stream:
            data=json.loads(line)
            if data.get('request_id')==1:return data.get('data')
    raise AssertionError('mpv property missing')
try:
    sway=start([SWAY,'--unsupported-gpu','-c',str(root/'sway.conf')])
    display=wait(lambda:next((p for p in runtime.glob('wayland-*') if p.is_socket()),None),'Wayland')
    assert display.parent==runtime and str(display).startswith(str(root))
    env['WAYLAND_DISPLAY']=display.name
    env['SWAYSOCK']=str(wait(lambda:next(iter(runtime.glob('sway-ipc.*.sock')),None),'Sway IPC'))
    subprocess.run(['ffmpeg','-v','error','-y','-f','lavfi','-i','testsrc2=size=320x180:rate=15','-t','20','-c:v','libx264','-pix_fmt','yuv420p',str(root/'fixture.mp4')],check=True,stdout=log,stderr=log,timeout=20)
    player=start(['mpv','--no-config','--vo=wlshm','--no-audio','--fullscreen','--loop-file=inf','--input-ipc-server='+str(root/'mpv.sock'),str(root/'fixture.mp4')])
    wait(lambda:(root/'mpv.sock').is_socket(),'MPV IPC')
    wait(lambda:(mpv('time-pos') or 0)>.4,'video playback')
    server=start([sys.executable,'-B',str(ROOT/'dotfiles/config/programs/flatpak/.local/lib/orgm-remote-desktop/remote.py'),'server'])
    endpoint=runtime/'orgm-remote-desktop/server.sock'
    wait(endpoint.is_socket,'private VNC socket')
    assert endpoint.stat().st_mode & 0o777==0o600
    # Seed ONLY the private compositor, including PRIMARY, before churn.
    for flags in ([], ['--primary']):
        subprocess.run(['wl-copy',*flags,'remote-fixture-clipboard'],env=env,check=True,stdout=log,stderr=log)
    for _ in range(12):
        probe=Client(endpoint);probe.close();time.sleep(.03)
        assert server.poll() is None, 'clipboard reconnect killed server; '+str(root)
    client=Client(endpoint)
    wait(lambda:(frame if len(set(frame:=client.frame()))>8 else None),'nonblank captured video frame')
    assert not mpv('pause')
    client.key(32)
    wait(lambda:mpv('pause') is True,'VNC keyboard pauses OWN test video')
    client.key(32)
    wait(lambda:mpv('pause') is False,'VNC keyboard resumes OWN test video')
    before=mpv('time-pos')
    client.close();time.sleep(1.2)
    after=mpv('time-pos')
    assert player.poll() is None and server.poll() is None
    assert not mpv('pause') and after>before+.5,(before,after)
    second=Client(endpoint);second.frame();second.close()
    print('PASS: seeded CLIPBOARD/PRIMARY reconnect churn, real private video, framebuffer, keyboard; playback survives disconnect')
    if os.environ.get('ORGM_TEST_REMOTE_FLATPAK')=='1':
        # Real registry/HOME for Flatpak, but private display, private session bus,
        # disposable app config and a socket containing ONLY the fixture video.
        appenv=dict(os.environ,WAYLAND_DISPLAY=str(display),XDG_CURRENT_DESKTOP='sway')
        for key in ('DISPLAY','SWAYSOCK','HYPRLAND_INSTANCE_SIGNATURE','DBUS_SESSION_BUS_ADDRESS'):
            appenv.pop(key,None)
        profile=root/'fixture.remmina'
        profile.write_text('[remmina]\nname=Isolated fixture\nprotocol=VNC\nserver=unix://'+str(endpoint)+'\ndisablepasswordstoring=1\nviewonly=1\nquality=2\ncolordepth=32\n')
        runner=root/'private-bus.sh'
        import shlex
        runner.write_text('HOME='+shlex.quote(str(root))+' XDG_CONFIG_HOME='+shlex.quote(str(root/'keyring-config'))+' XDG_DATA_HOME='+shlex.quote(str(root/'keyring-data'))+' '+shlex.quote(shutil.which('gnome-keyring-daemon'))+' --foreground --components=secrets --control-directory='+shlex.quote(str(root/'keyring'))+' &\ngdbus wait --session --timeout 10 org.freedesktop.secrets\nexec "$@"\n')
        viewer=start(['dbus-run-session','--','sh',str(runner),'flatpak','run','--no-documents-portal','--nosocket=x11','--nosocket=fallback-x11','--socket=wayland','--filesystem='+str(root),'--command=sh','--env=GSETTINGS_BACKEND=memory','--env=GIO_USE_VFS=local','--env=GDK_BACKEND=wayland','--env=G_MESSAGES_DEBUG=remmina','org.remmina.Remmina','-c','export XDG_CONFIG_HOME="$1/app-config" XDG_DATA_HOME="$1/app-data" XDG_CACHE_HOME="$1/app-cache" XDG_STATE_HOME="$1/app-state"; shift; exec remmina "$@"','fixture',str(root),'--disable-news','--connect',str(profile)],appenv)
        def connected():
            result=subprocess.run(['wayvncctl','-S',str(runtime/'orgm-remote-desktop/control.sock'),'-j','client-list'],capture_output=True,text=True,timeout=3)
            try:
                data=json.loads(result.stdout)
                return data.get('data') if isinstance(data,dict) else data
            except ValueError:return None
        wait(connected,'real Flatpak Remmina Unix connection',20)
        assert viewer.poll() is None
        print('PASS: real Remmina Flatpak private GUI connects private Unix endpoint without fragile precommands')
    print('EVIDENCE:',root,'video-time',round(before,2),'->',round(after,2))
finally:
    for child in reversed(children):
        if child.poll() is None:
            os.killpg(child.pid,signal.SIGTERM)
            try:child.wait(timeout=5)
            except subprocess.TimeoutExpired:os.killpg(child.pid,signal.SIGKILL);child.wait()
    log.close()
