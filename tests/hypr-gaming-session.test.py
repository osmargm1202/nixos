#!/usr/bin/env python3
"""X11 activation and game-policy lifecycle in private mount/network namespaces.

Opt-in: ORGM_TEST_PARENT_DISPLAY points to the real Wayland socket only as a
nested backend. Its X11 sockets, bus, input and game processes are never used.
"""
import ctypes as C,glob,json,os,re,shutil,signal,subprocess,sys,tempfile,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
parent=os.environ.get('ORGM_TEST_PARENT_DISPLAY')
if not parent:
 print('SKIP: explicit parent Wayland socket required for isolated gaming test');raise SystemExit(0)
if '--isolated' not in sys.argv:
 parent=Path(parent)
 if not parent.is_absolute():parent=Path(os.environ['XDG_RUNTIME_DIR'])/parent
 assert parent.is_socket()
 bwrap=shutil.which('bwrap') or glob.glob('/nix/store/*-bubblewrap-*/bin/bwrap')[-1]
 def identity(p):
  s=p.lstat();return (s.st_ino,s.st_mode,str(p.readlink()) if p.is_symlink() else '')
 before={p:identity(p) for p in list(Path('/tmp/.X11-unix').glob('*'))+list(Path('/tmp').glob('.X[0-9]*-lock'))}
 with tempfile.TemporaryDirectory(prefix='gaming-ns-') as private:
  env=dict(os.environ,ORGM_TEST_PARENT_DISPLAY=str(parent))
  args=[bwrap,'--bind','/','/','--dev','/dev','--dir','/dev/dri']
  # Render-only access, no physical input, VT or DRM master nodes in this test.
  for device in sorted(glob.glob('/dev/dri/renderD*')+glob.glob('/dev/nvidia*')):
   if Path(device).is_char_device():args+=['--dev-bind',device,device]
  args+=['--bind',private,'/tmp','--unshare-net','--die-with-parent',sys.executable,str(Path(__file__).resolve()),'--isolated']
  result=subprocess.run(args,env=env,timeout=180)
 for p,value in before.items():assert identity(p)==value,'Parent X11 socket/lock changed: '+str(p)
 assert result.returncode==0,result.returncode
 print('PASS: original desktop X11 socket/lock identities preserved',flush=True)
 raise SystemExit(0)
# All paths below /tmp now live in a private mount; abstract sockets are private too.
with tempfile.TemporaryDirectory(prefix='gg-') as tmp:
 home=Path(tmp);runtime=home/'r';runtime.mkdir(mode=0o700);binary=home/'bin';binary.mkdir()
 for name in ('pgrep','notify-send','wallpaper'):
  p=binary/name;p.write_text('#!/bin/sh\nexit 0\n');p.chmod(0o755)
 env=dict(os.environ,HOME=tmp,XDG_CONFIG_HOME=tmp+'/.config',XDG_CACHE_HOME=tmp+'/.cache',XDG_STATE_HOME=tmp+'/.state',XDG_DATA_HOME=tmp+'/.data',XDG_RUNTIME_DIR=str(runtime),PATH=str(binary)+os.pathsep+os.environ['PATH'],DBUS_SESSION_BUS_ADDRESS='unix:path='+tmp+'/no-bus',DBUS_SYSTEM_BUS_ADDRESS='unix:path='+tmp+'/no-system-bus',LIBSEAT_BACKEND='logind',HYPR_WALLPAPER_BIN=str(binary/'wallpaper'),HYPRLAND_NO_SD_VARS='1',HYPRLAND_NO_SD_NOTIFY='1',HYPRLAND_NO_RT='1',AQ_DRM_DEVICES='/dev/null')
 for key in ('DISPLAY','WAYLAND_DISPLAY','WAYLAND_SOCKET','HYPRLAND_INSTANCE_SIGNATURE','SWAYSOCK','I3SOCK'):env.pop(key,None)
 base=ROOT/'dotfiles/config/profiles/hyprland/.config/hypr'
 config=home/'hyprland.lua';config.write_text('package.path='+json.dumps(str(base/'?.lua'))+'..";"..package.path\n'
  +'hl.monitor({output="",mode="1280x800@60",position="0x0",scale=1})\n'
  +'require("lua.layout");require("lua.look-and-feel");require("lua.window-rules")\n'
  +'hl.config({general={layout="scrolling"},animations={enabled=false},input={follow_mouse=0},debug={disable_logs=false,enable_stdout_logs=true}})\n')
 log=(home/'session.log').open('w');children=[];display=None
 def start(*args):
  p=subprocess.Popen(args,env=env,stdout=log,stderr=log,start_new_session=True);children.append(p);return p
 def cmd(*args):return subprocess.check_output(args,env=env,text=True,timeout=8)
 def wait(probe,label):
  end=time.monotonic()+12
  while time.monotonic()<end:
   result=probe()
   if result:return result
   assert compositor.poll() is None,'nested compositor exited'
   time.sleep(.08)
  raise AssertionError('Timeout '+label)
 def clients():return json.loads(cmd('hyprctl','-j','clients'))
 def client(name):return next((c for c in clients() if c['class']==name),None)
 def focus(name):cmd('hyprctl','dispatch','hl.dsp.focus({window="address:'+client(name)['address']+'"})')
 def active():return json.loads(cmd('hyprctl','-j','activewindow')).get('class')
 def prop(name,key):return cmd('hyprctl','getprop','address:'+client(name)['address'],key).strip()
 def option(name):
  d=json.loads(cmd('hyprctl','-j','getoption',name));return d.get('int',d.get('bool'))
 def fullscreen(name,enabled):
  focus(name);cmd('hyprctl','dispatch','hl.dsp.window.fullscreen({mode="fullscreen",action="'+('set' if enabled else 'unset')+'"})')
 def mode(*args):cmd(str(ROOT/'dotfiles/config/users/osmarg/profiles/hyprland/.local/bin/hypr-game-mode'),*args)
 try:
  env['WAYLAND_DISPLAY']=os.environ['ORGM_TEST_PARENT_DISPLAY']
  compositor=start(os.environ.get('ORGM_TEST_HYPRLAND_BINARY','/run/current-system/sw/bin/Hyprland'),'--config',str(config))
  ipc=wait(lambda:next(runtime.glob('hypr/*/.socket.sock'),None),'private IPC');env['HYPRLAND_INSTANCE_SIGNATURE']=ipc.parent.name
  wayland=wait(lambda:next((p for p in runtime.glob('wayland-*') if p.is_socket()),None),'private Wayland');env['WAYLAND_DISPLAY']=wayland.name
  lock=wait(lambda:next(Path('/tmp').glob('.X[0-9]*-lock'),None),'private X11 lock')
  assert int(lock.read_text().strip())==compositor.pid,'X server must belong to private compositor'
  env['DISPLAY']=':'+re.search(r'X([0-9]+)-lock',lock.name).group(1)
  wait(lambda:Path('/tmp/.X11-unix/X'+env['DISPLAY'][1:]).is_socket(),'private X11 socket')
  assert not cmd('hyprctl','configerrors').strip()
  for name,workspace in [('game-control',1),('dota2',2),('steam_app_570',3),('steam',4)]:
   cmd('hyprctl','dispatch','hl.dsp.focus({workspace='+str(workspace)+'})')
   start('kitty','--config','NONE','--class',name,'-o','linux_display_server=x11','-o','confirm_os_window_close=0','sh','-c','sleep 100')
   wait(lambda:client(name),name+' X11 mapped')
  for path in glob.glob('/nix/store/*libx11-*/lib/libX11.so.6')+glob.glob('/nix/store/*libX11-*/lib/libX11.so.6'):
   try:x=C.CDLL(path);break
   except OSError:continue
  else:raise AssertionError('native libX11 missing')
  D=C.c_void_p;W=C.c_ulong
  x.XOpenDisplay.argtypes=[C.c_char_p];x.XOpenDisplay.restype=D
  x.XCloseDisplay.argtypes=[D];x.XDefaultRootWindow.argtypes=[D];x.XDefaultRootWindow.restype=W
  x.XQueryTree.argtypes=[D,W,C.POINTER(W),C.POINTER(W),C.POINTER(C.POINTER(W)),C.POINTER(C.c_uint)]
  x.XFree.argtypes=[D];x.XInternAtom.argtypes=[D,C.c_char_p,C.c_int];x.XInternAtom.restype=W
  x.XFlush.argtypes=[D];x.XSendEvent.argtypes=[D,W,C.c_int,C.c_long,D]
  class Hint(C.Structure):_fields_=[('name',D),('cls',D)]
  x.XGetClassHint.argtypes=[D,W,C.POINTER(Hint)]
  class Data(C.Union):_fields_=[('b',C.c_char*20),('s',C.c_short*10),('l',C.c_long*5)]
  class Message(C.Structure):_fields_=[('type',C.c_int),('serial',W),('send_event',C.c_int),('display',D),('window',W),('message_type',W),('format',C.c_int),('data',Data)]
  class Event(C.Union):_fields_=[('message',Message),('pad',C.c_long*24)]
  display=x.XOpenDisplay(env['DISPLAY'].encode());assert display,'private XOpenDisplay'
  root=x.XDefaultRootWindow(display)
  def find(name,parent=root):
   rootret=W();parentret=W();childrenptr=C.POINTER(W)();count=C.c_uint()
   assert x.XQueryTree(display,parent,C.byref(rootret),C.byref(parentret),C.byref(childrenptr),C.byref(count))
   ids=[childrenptr[i] for i in range(count.value)]
   if childrenptr:x.XFree(childrenptr)
   for window in ids:
    hint=Hint()
    if x.XGetClassHint(display,window,C.byref(hint)):
     cls=C.string_at(hint.cls).decode() if hint.cls else ''
     if hint.name:x.XFree(hint.name)
     if hint.cls:x.XFree(hint.cls)
     if cls==name:return window
   raise AssertionError('Missing private WM_CLASS '+name)
  def request(name):
   event=Event();event.message=Message(type=33,send_event=1,display=display,window=find(name),message_type=x.XInternAtom(display,b'_NET_ACTIVE_WINDOW',0),format=32)
   event.message.data.l[0]=1
   assert x.XSendEvent(display,root,0,(1<<20)|(1<<19),C.byref(event));x.XFlush(display)
  assert option('misc:focus_on_activate')==False
  for name in ('dota2','steam_app_570'):
   focus('game-control');request(name);wait(lambda:active()==name,'per-game X11 activation switches workspace/focus')
  focus('game-control');request('steam');time.sleep(.3);assert active()=='game-control','Steam client must not steal focus'
  assert option('general:allow_tearing')==False and option('misc:vrr')==0
  fullscreen('dota2',True);mode('on')
  wait(lambda:prop('dota2','render_unfocused')=='true','mode on enables fullscreen game background rendering')
  assert prop('steam','render_unfocused')=='false' and prop('steam_app_570','render_unfocused')=='false'
  fullscreen('dota2',False);wait(lambda:prop('dota2','render_unfocused')=='false','windowed game does not force background rendering')
  fullscreen('dota2',True);mode('vrr','on');mode('tearing','on')
  assert option('general:allow_tearing')==True and option('misc:vrr')==2
  assert prop('dota2','immediate')=='true' and prop('steam','immediate')=='false'
  mode('off');assert option('general:allow_tearing')==False and option('misc:vrr')==0
  assert prop('dota2','render_unfocused')=='false' and prop('dota2','immediate')=='false'
  assert prop('dota2','focus_on_activate')=='true'
  assert json.loads(cmd(str(ROOT/'dotfiles/config/users/osmarg/profiles/hyprland/.local/bin/hypr-game-mode'),'options'))==dict(vrr=True,tearing=True)
  mode('on');assert option('misc:vrr')==2 and prop('dota2','render_unfocused')=='true'
  mode('off');assert not cmd('hyprctl','configerrors').strip()
  # Real Wayland app_ids map to full columns, without fullscreen or floating.
  monitor=json.loads(cmd('hyprctl','-j','monitors'))[0]
  width=monitor['width']/monitor['scale']
  cmd('hyprctl','dispatch','hl.dsp.focus({workspace=5})')
  craft_apps=('cadcraft','photocraft','vectorcraft','filmcraft','lightcraft','pdfcraft',
              'effectcraft','designcraft','figcraft','wordcraft','soundcraft','deckcraft','gridcraft')
  for name in tuple('ai.storyteller.'+app for app in craft_apps)+('artcraft-launcher','CADCraft','artcraft-width-control'):
   process=start('kitty','--config','NONE','--class',name,'--title','CADCraft','-o','linux_display_server=wayland','-o','confirm_os_window_close=0','sh','-c','sleep 100')
   wait(lambda:client(name),name+' Wayland mapped')
   wide=name!='artcraft-width-control'
   wait(lambda:(client(name)['size'][0] > .9*width) if wide else (client(name)['size'][0] < .7*width),name+' scrolling column geometry')
   window=client(name)
   assert not window['xwayland'] and not window['floating'] and window['fullscreen']==0,(name,window)
   process.terminate();process.wait(timeout=5)
   wait(lambda:client(name) is None,name+' closed')
  print('PASS: 13 ArtCraft app_ids, launcher/binary aliases map at100% without fullscreen; title-only negative retains default width',flush=True)
  print('PASS: isolated real X11 game activation, Steam negative, fullscreen background lifecycle and optional VRR/tearing restoration',flush=True)
 except Exception:
  log.flush();text=(home/'session.log').read_text(errors='replace');print('\n'.join(line for line in text.splitlines() if re.search('ERR|CRIT|[Ff]ail|[Aa]llocat|[Rr]ender|[Gg][Bb][Mm]',line))[-8000:]);print(text[-2500:])
  for extra in runtime.glob('hypr/*/hyprland.log'):print(extra.read_text(errors='replace')[-5000:])
  raise
 finally:
  if display:x.XCloseDisplay(display)
  for p in reversed(children):
   if p.poll() is None:os.killpg(p.pid,signal.SIGTERM)
   try:p.wait(timeout=5)
   except subprocess.TimeoutExpired:os.killpg(p.pid,signal.SIGKILL);p.wait()
  log.close()
