#!/usr/bin/env python3
"""Actual themed Rofi selection in a private Sway; SSH/VNC effects are spies."""
import json,os,pathlib,shutil,signal,subprocess,sys,tempfile,time
P=pathlib.Path;ROOT=P(__file__).resolve().parents[1]
if not all(shutil.which(x) for x in ('sway','wtype','rofi')):
 print('SKIP: explicit private Sway/wtype/Rofi tools required');raise SystemExit(0)
with tempfile.TemporaryDirectory(prefix='remote-menu-') as temp:
 home=P(temp);runtime=home/'run';runtime.mkdir(mode=0o700);binary=home/'bin';binary.mkdir()
 for rel in ('.local/lib/orgm-wayland','.config/rofi-sway'):
  shutil.copytree(ROOT/'dotfiles/config/profiles'/('wayland' if rel.startswith('.local') else 'sway')/rel,home/rel,ignore=shutil.ignore_patterns('__pycache__'))
 helper=home/'.local/bin/orgm-rofi';helper.parent.mkdir(parents=True);shutil.copy2(ROOT/'dotfiles/config/profiles/wayland/.local/bin/orgm-rofi',helper)
 calls=home/'ssh.json';done=home/'desktop.json'
 kitty=binary/'kitty';kitty.write_text('#!'+sys.executable+'\nimport json,sys\nfrom pathlib import Path\nPath('+repr(str(calls))+').write_text(json.dumps(sys.argv[1:]))\n');kitty.chmod(0o755)
 (home/'sway.conf').write_text('xwayland disable\noutput HEADLESS-1 mode 1280x720\nseat seat0 fallback true\n')
 env=dict(os.environ,HOME=temp,USER='fixture',LOGNAME='fixture',XDG_RUNTIME_DIR=str(runtime),XDG_CONFIG_HOME=temp+'/.config',XDG_DATA_HOME=temp+'/.data',XDG_CACHE_HOME=temp+'/.cache',XDG_STATE_HOME=temp+'/.state',DBUS_SESSION_BUS_ADDRESS='unix:path='+temp+'/no-bus',XDG_CURRENT_DESKTOP='sway',WLR_BACKENDS='headless',WLR_RENDERER='pixman',WLR_LIBINPUT_NO_DEVICES='1',PATH=str(binary)+':'+str(helper.parent)+':'+os.environ['PATH'])
 for k in ('DISPLAY','WAYLAND_DISPLAY','WAYLAND_SOCKET','SWAYSOCK','HYPRLAND_INSTANCE_SIGNATURE'):env.pop(k,None)
 log=(home/'log').open('w');children=[]
 def start(args):
  p=subprocess.Popen(args,env=env,stdout=log,stderr=log,start_new_session=True);children.append(p);return p
 try:
  compositor=start(['sway','--unsupported-gpu','-c',str(home/'sway.conf')]);end=time.monotonic()+8
  while time.monotonic()<end and not any(p.is_socket() for p in runtime.glob('wayland-*')):time.sleep(.05)
  env['WAYLAND_DISPLAY']=next(p.name for p in runtime.glob('wayland-*') if p.is_socket())
  for desktop in (False,True):
   runner=home/'runner.py'
   runner.write_text('import runpy\nfrom pathlib import Path\nm=runpy.run_path('+repr(str(ROOT/'dotfiles/config/programs/flatpak/.local/lib/orgm-remote-desktop/connections.py'))+')\nm["interactive"].__globals__["discover"]=lambda peers:[dict(name="fixture",host="server.example.ts.net",online=True,desktop='+repr('fixture' if desktop else None)+',user="fixture")]\nm["interactive"]({},lambda name:Path('+repr(str(done))+').write_text(name))\n')
   client=start([sys.executable,'-B',str(runner)]);end=time.monotonic()+12
   # All events target ONLY the private display. Repeated Return traverses
   # real menus while backend side effects are fixture-owned spies.
   while time.monotonic()<end and client.poll() is None:
    subprocess.run(['wtype','-s','350','-k','Return'],env=env,check=True,stdout=log,stderr=log)
   assert client.wait(timeout=2)==0,(home/'log').read_text()
   if desktop:assert done.read_text()=='fixture'
   else:
    deadline=time.monotonic()+3
    while not calls.exists() and time.monotonic()<deadline:time.sleep(.05)
    argv=json.loads(calls.read_text());assert argv[:2]==['-e','ssh'] and argv[-3:]==['-l','fixture','server.example.ts.net'],argv
    assert not any('id_ed25519' in a for a in argv)
  print('PASS: actual private themed Rofi device/protocol/user selection, normal SSH argv and prepared-desktop dispatch')
 except Exception:
  log.flush();print((home/'log').read_text(errors='replace')[-3500:]);raise
 finally:
  for p in reversed(children):
   if p.poll() is None:
    os.killpg(p.pid,signal.SIGTERM)
    try:p.wait(timeout=3)
    except subprocess.TimeoutExpired:os.killpg(p.pid,signal.SIGKILL);p.wait()
  log.close()
