#!/usr/bin/env python3
"""Private two-output Sway: external-only nonzero origin must remain shareable."""
import json,os,pathlib,shutil,signal,subprocess,sys,tempfile,time
sys.dont_write_bytecode=True
sys.path.insert(0,str(pathlib.Path(__file__).parent/'helpers'))
from rfb import Client
P=pathlib.Path;ROOT=P(__file__).resolve().parents[1]
if not shutil.which('sway') or not shutil.which('wayvnc'):
 print('SKIP: explicit native Sway/WayVNC test tools required');raise SystemExit(0)
root=P(tempfile.mkdtemp(prefix='remote-hotplug-'));runtime=root/'run';runtime.mkdir(mode=0o700)
cfg=root/'sway.conf';cfg.write_text('xwayland disable\noutput HEADLESS-1 mode 640x360 pos 0 0 bg #336699 solid_color\noutput HEADLESS-2 mode 640x360 pos 640 0 bg #663399 solid_color\nseat seat0 fallback true\n')
env=dict(os.environ,HOME=str(root),XDG_RUNTIME_DIR=str(runtime),DBUS_SESSION_BUS_ADDRESS='unix:path='+str(root/'no-bus'),WLR_BACKENDS='headless',WLR_HEADLESS_OUTPUTS='2',WLR_RENDERER='pixman',WLR_LIBINPUT_NO_DEVICES='1')
for key in ('DISPLAY','WAYLAND_DISPLAY','WAYLAND_SOCKET','SWAYSOCK','HYPRLAND_INSTANCE_SIGNATURE'):env.pop(key,None)
log=(root/'server.log').open('w');children=[]
def start(args):
 p=subprocess.Popen(args,env=env,stdout=log,stderr=log,start_new_session=True);children.append(p);return p
def wait(probe,label):
 end=time.monotonic()+8
 while time.monotonic()<end:
  value=probe()
  if value:return value
  time.sleep(.05)
 raise AssertionError(label+'; '+str(root))
def msg(command):
 result=json.loads(subprocess.check_output(['swaymsg','-r',command],env=env,text=True));assert all(r.get('success') for r in result),result
try:
 compositor=start(['sway','--unsupported-gpu','-c',str(cfg)])
 display=wait(lambda:next((p for p in runtime.glob('wayland-*') if p.is_socket()),None),'private display')
 env['WAYLAND_DISPLAY']=display.name;env['SWAYSOCK']=str(next(runtime.glob('sway-ipc.*.sock')))
 server=start([sys.executable,'-B',str(ROOT/'dotfiles/config/programs/flatpak/.local/lib/orgm-remote-desktop/remote.py'),'server'])
 endpoint=runtime/'orgm-remote-desktop/server.sock';wait(endpoint.is_socket,'server socket')
 initial=Client(endpoint);initial.frame();initial.close()
 for command in ('output HEADLESS-1 disable','output HEADLESS-1 enable; output HEADLESS-2 disable','output HEADLESS-2 enable; output HEADLESS-1 disable'):
  msg(command);time.sleep(.35)
  assert server.poll() is None,'server died after '+command+'; '+str(root)
  client=Client(endpoint);frame=client.frame();assert frame;client.close()
  assert server.poll() is None,'server died on reconnect; '+str(root)
 print('PASS: private internal-off/external-only x640 capture and repeated hotplug/reconnect, same server process; evidence',root)
finally:
 for child in reversed(children):
  if child.poll() is None:
   os.killpg(child.pid,signal.SIGTERM)
   try:child.wait(timeout=4)
   except subprocess.TimeoutExpired:os.killpg(child.pid,signal.SIGKILL);child.wait()
 log.close()
