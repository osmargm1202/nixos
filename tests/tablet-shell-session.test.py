#!/usr/bin/env python3
"""Private Waybar + native app dock, larger icons and unchanged favorites."""
import glob,json,os,shutil,signal,subprocess,sys,tempfile,time,runpy
from pathlib import Path
from helpers.wayland_pointer import Pointer
# Native Sway/Hyprland nwg docks share a /tmp lock keyed only by user
# name. A private Wayland socket alone is NOT sufficient to isolate them.
if os.environ.get('ORGM_TEST_DOCK_ISOLATED')!='1':
 bwrap=os.environ.get('ORGM_TEST_BWRAP') or shutil.which('bwrap')
 if not bwrap:
  print('SKIP: bwrap required for native-dock process/lock isolation');raise SystemExit(0)
 os.execvpe(bwrap,[bwrap,'--die-with-parent','--unshare-pid','--unshare-ipc','--unshare-net','--bind','/','/','--proc','/proc','--dev-bind','/dev','/dev','--tmpfs','/tmp','--setenv','ORGM_TEST_DOCK_ISOLATED','1',sys.executable,'-B',__file__],os.environ)
ROOT=Path(os.environ.get('ORGM_TEST_REPO',Path(__file__).resolve().parents[1]))
PIXBUF=os.environ.get('ORGM_TEST_DOCK_PIXBUF') or next(iter(glob.glob('/nix/store/*-librsvg-*/lib/gdk-pixbuf-2.0/*/loaders.cache')),None)
assert PIXBUF,'supply librsvg loader cache for real native dock icons'
SWAY=os.environ.get('ORGM_TEST_SWAY') or shutil.which('sway') or glob.glob('/nix/store/*-swayfx-0.5.3/bin/sway')[0]
with tempfile.TemporaryDirectory(prefix='tablet-private-') as temp:
 home=Path(temp);runtime=home/'run';runtime.mkdir(mode=0o700);binary=home/'bin';binary.mkdir()
 env=dict(os.environ,HOME=temp,XDG_CONFIG_HOME=temp+'/.config',XDG_DATA_HOME=temp+'/.data',XDG_STATE_HOME=temp+'/.state',XDG_CACHE_HOME=temp+'/.cache',XDG_RUNTIME_DIR=str(runtime),DBUS_SESSION_BUS_ADDRESS='unix:path='+temp+'/no-bus',WLR_BACKENDS='headless',WLR_RENDERER='pixman',WLR_LIBINPUT_NO_DEVICES='1',QT_QPA_PLATFORM='wayland',GDK_PIXBUF_MODULE_FILE=PIXBUF,ORGM_DESKTOP_COMPOSITOR='sway',PATH=str(binary)+os.pathsep+str(Path(SWAY).parent)+os.pathsep+os.environ['PATH'])
 for k in ('DISPLAY','WAYLAND_DISPLAY','SWAYSOCK','HYPRLAND_INSTANCE_SIGNATURE','WAYLAND_SOCKET','QS_CONFIG_PATH','QS_CONFIG_NAME'):env.pop(k,None)
 calls=home/'calls.jsonl'
 for name in ('sway-app-launcher','orgm-sway','orgm-osk','normal-dock'):
  p=binary/name;p.write_text('#!'+sys.executable+'\nimport json,sys\nfrom pathlib import Path\np=Path('+repr(str(calls))+')\nwith p.open("a") as f:f.write(json.dumps([Path(sys.argv[0]).name]+sys.argv[1:])+"\\n")\n');p.chmod(0o755)
 # Seed the real editable app ownership stack, including normal configuration.
 subprocess.run(['orgm-dot','--repo',str(ROOT),'--home',temp,'--profile','sway','--user','osmarg','--host','envy','pull','wayland-tools'],check=True,capture_output=True)
 for directory in ('.config/waybar',):
  shutil.copytree(ROOT/'dotfiles/config/profiles/sway'/directory,home/directory,dirs_exist_ok=True)
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
  wrapper=home/'.local/bin/orgm-session-dock'
  subprocess.run([str(wrapper),'sway',str(binary/'normal-dock'),'normal-argument'],env=env,check=True)
  assert ['normal-dock','normal-argument'] in events(),'normal dock command must be untouched'
  pref=home/'.state/orgm-tablet/preferences.json';pref.parent.mkdir(parents=True);pref.write_text('{"mode":"on"}')
  subprocess.run([str(wrapper),'sway',str(binary/'normal-dock'),'-i','32','normal-argument'],env=env,check=True)
  assert events()==[['normal-dock','normal-argument'],['normal-dock','-i','48','normal-argument']],events()
  print('PASS: same native dock command/favorites policy; tablet icons32->48 only',flush=True)
  native=os.environ.get('ORGM_TEST_SWAY_DOCK') or shutil.which('nwg-dock')
  assert native,'supply the real Sway nwg-dock binary'
  shutil.copytree(ROOT/'dotfiles/config/profiles/sway/.config/nwg-dock',home/'.config/nwg-dock',dirs_exist_ok=True)
  apps=home/'.data/applications';apps.mkdir(parents=True)
  (apps/'tablet-fixture.desktop').write_text('[Desktop Entry]\nType=Application\nName=Fixture app\nExec=false\nIcon=utilities-terminal\n')
  shutil.copytree(ROOT/'dotfiles/config/profiles/sway/.local/share/nwg-dock',home/'.data/nwg-dock',dirs_exist_ok=True)
  # Native0.4.3 uses XDG_CONFIG_HOME for pins when XDG_CACHE_HOME is set.
  pins=home/'.config/nwg-dock-pinned';pins.parent.mkdir(parents=True,exist_ok=True);pins.write_text('tablet-fixture\n');saved_pins=pins.read_bytes()
  dock=start(str(wrapper),'sway',native,'-p','right','-i','32','-w','10','-nows','-mr','6','-l','top','-c','sway-app-launcher')
  wait(lambda:b'-i\x0048\x00' in Path('/proc/'+str(dock.pid)+'/cmdline').read_bytes(),'actual enlarged native dock')
  assert pins.read_bytes()==saved_pins
  pointer=Pointer(display)
  source=home/'.config/waybar/config'
  value=json.loads(source.read_text());value['idle_inhibitor']['start-activated']=True;source.write_text(json.dumps(value))
  generated=cmd(str(home/'.local/bin/orgm-tablet'),'bar-config',str(home/'.config/waybar/config'),'sway').strip()
  style=cmd(str(home/'.local/bin/orgm-tablet'),'bar-style',str(home/'.config/waybar/style.css')).strip()
  bar=start('waybar','-c',generated,'-s',style);time.sleep(.8);assert bar.poll() is None,'actual Waybar must load profile/CSS'
  assert dock.poll() is None and pins.read_bytes()==saved_pins
  # Prove actual native app icons render, not just a living PID/argv. This
  # region excludes Waybar and contains only our fixture dock on black.
  pixels=subprocess.check_output(['grim','-t','ppm','-g','1150,52 130x748','-'],env=env).split(b'\n',3)[-1]
  assert max(pixels)>100 and len(set(pixels))>8,'native dock has no visible icons'
  if os.environ.get('ORGM_TEST_TABLET_SCREENSHOT'):cmd('grim',os.environ['ORGM_TEST_TABLET_SCREENSHOT'])
  click(dict(x=1215,y=1,width=55,height=50))
  wait(lambda:['orgm-sway','control'] in events(),'actual large Waybar control button')
  print('PASS: real large/reduced Waybar and control-center touch target',flush=True)
  idle=home/'idle-fired'
  swayidle=os.environ.get('ORGM_TEST_SWAYIDLE') or shutil.which('swayidle') or glob.glob('/nix/store/*-swayidle-*/bin/swayidle')[0]
  start(swayidle,'-w','timeout','1','touch '+str(idle))
  time.sleep(2.1)
  assert not idle.exists(),'Caffeine must actually inhibit the private compositor in tablet mode'
  os.killpg(bar.pid,signal.SIGTERM);bar.wait(timeout=3)
  wait(lambda:idle.exists(),'inhibitor released when test Waybar stops')
  print('PASS: actual idle-notify remains inhibited by tablet Caffeine and resumes after bar exit',flush=True)
 except Exception:
  log.flush();print((home/'session.log').read_text(errors='replace')[-4000:]);raise
 finally:
  if pointer:pointer.close()
  for p in reversed(children):
   if p.poll() is None:os.killpg(p.pid,signal.SIGTERM)
   try:p.wait(timeout=3)
   except subprocess.TimeoutExpired:os.killpg(p.pid,signal.SIGKILL);p.wait()
  log.close()
  if os.environ.get('ORGM_TEST_TABLET_LOG'):shutil.copy2(home/'session.log',os.environ['ORGM_TEST_TABLET_LOG'])
