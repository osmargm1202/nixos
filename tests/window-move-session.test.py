#!/usr/bin/env python3
"""Real Shift+arrows on private Sway/Hyprland, never the parent's input socket.

Sway uses headless outputs. Hyprland is opt-in with ORGM_TEST_PARENT_DISPLAY.
"""
import glob,json,os,shutil,signal,subprocess,tempfile,time
from pathlib import Path
from helpers.wayland_pointer import Pointer
from helpers.wayland_keyboard import Keyboard
ROOT=Path(__file__).resolve().parents[1]
MODE=os.environ.get('ORGM_TEST_COMPOSITOR','sway')
assert MODE in ('sway','hyprland')
if MODE=='hyprland' and not os.environ.get('ORGM_TEST_PARENT_DISPLAY'):
 print('SKIP: private Hyprland needs explicit ORGM_TEST_PARENT_DISPLAY');raise SystemExit(0)
with tempfile.TemporaryDirectory(prefix='wm-') as tmp:
 home=Path(tmp);runtime=home/'r';runtime.mkdir(mode=0o700)
 env=dict(os.environ,HOME=tmp,XDG_CONFIG_HOME=tmp+'/.config',XDG_CACHE_HOME=tmp+'/.cache',
  XDG_STATE_HOME=tmp+'/.state',XDG_DATA_HOME=tmp+'/.data',XDG_RUNTIME_DIR=str(runtime),
  DBUS_SESSION_BUS_ADDRESS='unix:path='+tmp+'/no-bus',HYPRLAND_NO_SD_VARS='1',
  HYPRLAND_NO_SD_NOTIFY='1',HYPRLAND_NO_RT='1')
 for k in ('WAYLAND_DISPLAY','WAYLAND_SOCKET','DISPLAY','SWAYSOCK','I3SOCK','HYPRLAND_INSTANCE_SIGNATURE','QS_CONFIG_PATH','QS_CONFIG_NAME'):
  env.pop(k,None)
 config=home/('hyprland.lua' if MODE=='hyprland' else 'sway.conf')
 if MODE=='hyprland':
  base=ROOT/'dotfiles/config/profiles/hyprland/.config/hypr'
  personal=ROOT/'dotfiles/config/users/osmarg/profiles/hyprland/.config/hypr/lua/keybindings.lua'
  config.write_text('package.path='+json.dumps(str(base/'?.lua'))+'..";"..package.path\n'
   +'hl.monitor({output="",mode="1280x800@60",position="0x0",scale=1})\n'
   +'require("lua.layout")\n'
   +'hl.config({general={layout="scrolling"},animations={enabled=false},input={follow_mouse=0}})\n'
   +'dofile('+json.dumps(str(personal))+').setup({terminal="kitty",fileManager="nautilus"})\n')
  parent=Path(os.environ['ORGM_TEST_PARENT_DISPLAY'])
  if not parent.is_absolute():parent=Path(os.environ['XDG_RUNTIME_DIR'])/parent
  env.update(WAYLAND_DISPLAY=str(parent),AQ_DRM_DEVICES='/dev/null')
  compositor_args=['Hyprland','--config',str(config)]
 else:
  source=(ROOT/'dotfiles/config/profiles/sway/.config/sway/config').read_text().splitlines()
  binds=[line for line in source if any(line.startswith('bindsym $mod+'+mod+'+'+key+' ') for mod in ('Shift','Ctrl') for key in ('Left','Right','Up','Down'))]
  config.write_text('set $mod Mod4\nxwayland disable\noutput HEADLESS-1 mode 1280x800\nfont pango:monospace 10\n'
   +'focus_follows_mouse no\ndefault_border none\n'+"\n".join(binds)+'\n')
  env.update(WLR_BACKENDS='headless',WLR_RENDERER='pixman',WLR_LIBINPUT_NO_DEVICES='1')
  sway=os.environ.get('ORGM_TEST_SWAY') or shutil.which('sway') or glob.glob('/nix/store/*-swayfx-0.5.3/bin/sway')[0]
  env['PATH']=str(Path(sway).parent)+os.pathsep+os.environ['PATH']
  compositor_args=[sway,'--unsupported-gpu','-c',str(config)]
 log=(home/'session.log').open('w');children=[];pointer=None
 def start(*args):
  p=subprocess.Popen(args,env=env,stdout=log,stderr=log,start_new_session=True);children.append(p);return p
 def cmd(*args):return subprocess.check_output(args,env=env,text=True,timeout=8)
 def wait(probe,label):
  end=time.monotonic()+12
  while time.monotonic()<end:
   value=probe()
   if value:return value
   assert compositor.poll() is None,'compositor exited: '+(home/'session.log').read_text(errors='replace')[-2000:]
   time.sleep(.08)
  raise AssertionError('Timeout '+label)
 def nodes():
  if MODE=='hyprland':
   return {c['class']:{'id':c['address'],'x':c['at'][0],'y':c['at'][1],'w':c['size'][0],'h':c['size'][1],'floating':c['floating']} for c in json.loads(cmd('hyprctl','-j','clients'))}
  result={}
  def walk(n):
   if n.get('app_id'):
    r=n['rect'];result[n['app_id']]={'id':n['id'],'x':r['x'],'y':r['y'],'w':r['width'],'h':r['height'],'floating':n.get('type')=='floating_con'}
   for child in n.get('nodes',[])+n.get('floating_nodes',[]):walk(child)
  walk(json.loads(cmd('swaymsg','-t','get_tree')));return result
 def focus(name):
  if MODE=='hyprland':cmd('hyprctl','dispatch','hl.dsp.focus({window="address:'+nodes()[name]['id']+'"})')
  else:cmd('swaymsg','[con_id='+str(nodes()[name]['id'])+'] focus')
 def spawn(name):
  start('kitty','--config','NONE','--class',name,'-o','linux_display_server=wayland','-o','confirm_os_window_close=0','sh','-c','sleep 100')
  wait(lambda:name in nodes(),name+' mapped');time.sleep(.2)
 def key(direction,ctrl=False):
  keyboard.key(125,True);keyboard.key(29 if ctrl else 42,True);keyboard.modifiers(64|(4 if ctrl else 1))
  keyboard.key({'left':105,'right':106,'up':103,'down':108}[direction],True)
  keyboard.key({'left':105,'right':106,'up':103,'down':108}[direction],False)
  keyboard.modifiers(0);keyboard.key(29 if ctrl else 42,False);keyboard.key(125,False);time.sleep(.2)
 try:
  compositor=start(*compositor_args)
  if MODE=='hyprland':
   socket=wait(lambda:next(runtime.glob('hypr/*/.socket.sock'),None),'Hypr IPC')
   env['HYPRLAND_INSTANCE_SIGNATURE']=socket.parent.name
  else:env['SWAYSOCK']=str(wait(lambda:next(runtime.glob('sway-ipc.*.sock'),None),'Sway IPC'))
  display=wait(lambda:next((p for p in runtime.glob('wayland-*') if p.is_socket()),None),'private display')
  env['WAYLAND_DISPLAY']=display.name
  pointer=Pointer(display);keyboard=Keyboard(pointer)
  for name in ('move-a','move-b','move-c'):spawn(name)
  if MODE=='hyprland':
   assert not cmd('hyprctl','configerrors').strip()
   before=nodes();assert before['move-a']['x']!=before['move-b']['x']
   focus('move-b');key('left')
   wait(lambda:abs(nodes()['move-a']['x']-nodes()['move-b']['x'])<5,'Shift+Left moves into previous scrolling column')
   pair=sorted(('move-a','move-b'),key=lambda n:nodes()[n]['y']);top,bottom=pair
   assert nodes()[bottom]['y']>nodes()[top]['y']
   focus(bottom);key('up');wait(lambda:nodes()[bottom]['y']<nodes()[top]['y'],'Shift+Up reorders stacked windows')
   key('down');wait(lambda:nodes()[bottom]['y']>nodes()[top]['y'],'Shift+Down reorders stacked windows')
   key('right');wait(lambda:nodes()[bottom]['x']>nodes()[top]['x']+50,'Shift+Right changes scrolling column')
  else:
   focus('move-b');key('left');wait(lambda:nodes()['move-b']['x']<nodes()['move-a']['x'],'Shift+Left reorders horizontally')
   key('right');wait(lambda:nodes()['move-b']['x']>nodes()['move-a']['x'],'Shift+Right reorders horizontally')
   cmd('swaymsg','splitv');spawn('move-d')
   assert nodes()['move-d']['y']>nodes()['move-b']['y']
   key('up');wait(lambda:nodes()['move-d']['y']<nodes()['move-b']['y'],'Shift+Up reorders vertically')
   key('down');wait(lambda:nodes()['move-d']['y']>nodes()['move-b']['y'],'Shift+Down reorders vertically')
  # Also verify all directions on an isolated floating window, without neighbors.
  target='move-c';focus(target)
  if MODE=='hyprland':
   cmd('hyprctl','dispatch','hl.dsp.window.float({action="enable"})')
   cmd('hyprctl','dispatch','hl.dsp.window.resize({x=300,y=220})')
   cmd('hyprctl','dispatch','hl.dsp.window.move({x=400,y=300})')
  else:cmd('swaymsg','floating enable, resize set 300 220, move position 400 300')
  for ctrl in (False,True):
   for direction,axis,sign in [('left','x',-1),('right','x',1),('up','y',-1),('down','y',1)]:
    before=nodes()[target][axis];key(direction,ctrl=ctrl)
    wait(lambda:(nodes()[target][axis]-before)*sign>0,'floating '+('Ctrl' if ctrl else 'Shift')+'+'+direction)
  if MODE=='hyprland':assert not cmd('hyprctl','configerrors').strip()
  print('PASS: '+MODE+' real Shift+four arrows move tiled/stacked and floating windows',flush=True)
 except Exception:
  log.flush();print((home/'session.log').read_text(errors='replace')[-3000:]);raise
 finally:
  if pointer:pointer.close()
  for p in reversed(children):
   if p.poll() is None:os.killpg(p.pid,signal.SIGTERM)
   try:p.wait(timeout=4)
   except subprocess.TimeoutExpired:os.killpg(p.pid,signal.SIGKILL);p.wait()
  log.close()
