#!/usr/bin/env python3
"""Real private CC touch tests; only backend effects simulated, no real session."""
import glob,json,os,shutil,signal,subprocess,sys,tempfile,time,runpy
from pathlib import Path
from helpers.wayland_pointer import Pointer
ROOT=Path(__file__).resolve().parents[1]
SWAY=os.environ.get('ORGM_TEST_SWAY') or shutil.which('sway') or glob.glob('/nix/store/*-swayfx-0.5.3/bin/sway')[0]
with tempfile.TemporaryDirectory(prefix='tablet-private-') as temp:
 home=Path(temp);runtime=home/'run';runtime.mkdir(mode=0o700);binary=home/'bin';binary.mkdir()
 env=dict(os.environ,HOME=temp,XDG_CONFIG_HOME=temp+'/.config',XDG_STATE_HOME=temp+'/.state',XDG_CACHE_HOME=temp+'/.cache',XDG_RUNTIME_DIR=str(runtime),DBUS_SESSION_BUS_ADDRESS='unix:path='+temp+'/no-bus',WLR_BACKENDS='headless',WLR_RENDERER='pixman',WLR_LIBINPUT_NO_DEVICES='1',QT_QPA_PLATFORM='wayland',ORGM_DESKTOP_COMPOSITOR='sway',PATH=str(binary)+os.pathsep+str(Path(SWAY).parent)+os.pathsep+os.environ['PATH'])
 for k in ('DISPLAY','WAYLAND_DISPLAY','SWAYSOCK','HYPRLAND_INSTANCE_SIGNATURE','WAYLAND_SOCKET','QS_CONFIG_PATH','QS_CONFIG_NAME'):env.pop(k,None)
 calls=home/'calls.jsonl'
 for name in ('sway-app-launcher','orgm-sway','orgm-osk','normal-dock'):
  p=binary/name;p.write_text('#!'+sys.executable+'\nimport json,sys\nfrom pathlib import Path\np=Path('+repr(str(calls))+')\nwith p.open("a") as f:f.write(json.dumps([Path(sys.argv[0]).name]+sys.argv[1:])+"\\n")\n');p.chmod(0o755)
 ui=home/'.config/quickshell/orgm-wallpapers'
 shutil.copytree(ROOT/'dotfiles/config/profiles/wayland/.config/quickshell/orgm-wallpapers',ui)
 desktop=runpy.run_path(str(ROOT/'dotfiles/config/profiles/sway/.local/bin/orgm-sway-desktop'))
 controls=desktop['control_controls']()
 for c in controls:c['available']=True
 state=dict(brightness=50,dnd=False,gaming=False,caffeine=False,caffeineAvailable=True,
   tablet=dict(active=False,available=True,keyboardAvailable=True,keyboardVisible=False),
   controls=controls,battery='82% · Test',network='connected',powerProfile='balanced',media='Prueba privada')
 statefile=home/'state.json';statefile.write_text(json.dumps(state))
 backend=binary/'backend'
 backend.write_text('#!'+sys.executable+'\nimport json,sys\nfrom pathlib import Path\np=Path('+repr(str(statefile))+')\ns=json.loads(p.read_text())\nif sys.argv[1]=="control-action":\n a=sys.argv[2]\n if a=="tablet":s["tablet"]["active"]=not s["tablet"]["active"]\n if a=="keyboard":s["tablet"]["keyboardVisible"]=not s["tablet"]["keyboardVisible"]\n p.write_text(json.dumps(s))\nprint(json.dumps(s))\n');backend.chmod(0o755)
 data=home/'catalog.json';data.write_text(json.dumps(dict(kind='control',backend=str(backend),state=state)))
 result=home/'result';env.update(ORGM_WALLPAPER_DATA=str(data),ORGM_MENU_RESULT=str(result))
 config=home/'sway.conf';config.write_text('output HEADLESS-1 mode 1280x800\nfont pango:monospace 10\nxwayland disable\n')
 log=(home/'session.log').open('w');children=[];pointer=None
 def start(*args):
  p=subprocess.Popen(args,env=env,stdout=log,stderr=log,start_new_session=True);children.append(p);return p
 def cmd(*args):return subprocess.check_output(args,env=env,text=True,timeout=5)
 def wait(probe,label):
  end=time.monotonic()+10
  while time.monotonic()<end:
   try:
    value=probe()
    if value:return value
   except (subprocess.SubprocessError,ValueError):pass
   time.sleep(.08)
  raise AssertionError('Timeout '+label)
 def events():return [json.loads(v) for v in calls.read_text().splitlines()] if calls.exists() else []
 def click(rect):
  pointer.move(rect['x']+rect['width']/2,rect['y']+rect['height']/2,1280,800);pointer.button(True);pointer.button(False);time.sleep(.2)
 try:
  start('dbus-daemon','--session','--nofork','--address='+env['DBUS_SESSION_BUS_ADDRESS'])
  wait(lambda:(home/'no-bus').exists(),'private session bus')
  start(SWAY,'--unsupported-gpu','-c',str(config))
  display=wait(lambda:next((v for v in runtime.glob('wayland-*') if v.is_socket()),None),'display')
  env['WAYLAND_DISPLAY']=display.name;env['SWAYSOCK']=str(wait(lambda:next(runtime.glob('sway-ipc.*.sock'),None),'IPC'))
  shell=start('qs','--path',str(ui/'menus.qml'))
  def status():return json.loads(cmd('qs','--path',str(ui/'menus.qml'),'ipc','call','menu','status'))
  wait(lambda:len(status().get('controls') or [])>35,'complete native control center')
  pointer=Pointer(display)
  def control(name):return next(b for b in status()['controls'] if b['id']==name)
  assert control('tablet')['height']>=48
  click(control('tablet'));wait(lambda:status()['state']['tablet']['active'],'manual tablet click')
  wait(lambda:control('keyboard')['height']>=64,'large tablet controls')
  click(control('keyboard'));wait(lambda:status()['state']['tablet']['keyboardVisible'],'shared keyboard action')
  if os.environ.get('ORGM_TEST_UI_ARTIFACTS'):
   dest=Path(os.environ['ORGM_TEST_UI_ARTIFACTS']);dest.mkdir(parents=True,exist_ok=True)
   cmd('grim',str(dest/'control-landscape.png'))
   cmd('swaymsg','output','HEADLESS-1','mode','800x1280');time.sleep(.5)
   cmd('grim',str(dest/'control-portrait.png'))
   cmd('swaymsg','output','HEADLESS-1','mode','1280x800');time.sleep(.5)
  click(control('windows'));wait(lambda:result.exists() and result.read_text().strip()=='windows','window selector choice')
  print('PASS: native complete CC, manual mode click increases targets, shared keyboard and Windows choice; landscape/portrait',flush=True)
 except Exception:
  log.flush();print((home/'session.log').read_text(errors='replace')[-4000:]);raise
 finally:
  if pointer:pointer.close()
  for p in reversed(children):
   if p.poll() is None:os.killpg(p.pid,signal.SIGTERM)
   try:p.wait(timeout=3)
   except subprocess.TimeoutExpired:os.killpg(p.pid,signal.SIGKILL);p.wait()
  log.close()
