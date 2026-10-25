#!/usr/bin/env python3
"""Real private Sway reload of nwg-displays files; no live outputs/input."""
import json,os,pathlib,shutil,signal,subprocess,tempfile,time
P=pathlib.Path;ROOT=P(__file__).resolve().parents[1]
sway=os.environ.get('ORGM_TEST_SWAY') or shutil.which('sway')
if not sway:print('SKIP: native Sway required');raise SystemExit(0)
with tempfile.TemporaryDirectory(prefix='sway-displays-') as temporary:
 home=P(temporary);runtime=home/'run';runtime.mkdir(mode=0o700);config=home/'.config/sway';config.mkdir(parents=True)
 source=(ROOT/'dotfiles/config/profiles/sway/.config/sway/config').read_text()
 includes=[line for line in source.splitlines() if line.startswith('include ~/.config/sway/') and any(name in line for name in ('outputs','workspaces'))]
 (config/'outputs.conf').write_text('output HEADLESS-1 scale 1\n')
 (config/'workspaces.conf').write_text('# Local assignments retained\n')
 cfg=home/'sway.conf';cfg.write_text('xwayland disable\noutput HEADLESS-1 mode 1280x720\n'+ '\n'.join(includes)+'\n')
 env=dict(os.environ,HOME=temporary,XDG_CONFIG_HOME=str(home/'.config'),XDG_RUNTIME_DIR=str(runtime),DBUS_SESSION_BUS_ADDRESS='unix:path='+str(home/'no-bus'),WLR_BACKENDS='headless',WLR_HEADLESS_OUTPUTS='2',WLR_RENDERER='pixman',WLR_LIBINPUT_NO_DEVICES='1')
 for key in ('DISPLAY','WAYLAND_DISPLAY','WAYLAND_SOCKET','SWAYSOCK','HYPRLAND_INSTANCE_SIGNATURE'):env.pop(key,None)
 log=(home/'sway.log').open('w');child=subprocess.Popen([sway,'--unsupported-gpu','-c',str(cfg)],env=env,stdout=log,stderr=log,start_new_session=True)
 def query(kind):return json.loads(subprocess.check_output([str(P(sway).with_name('swaymsg')),'-r','-t',kind],env=env,text=True,timeout=5))
 try:
  deadline=time.monotonic()+8
  while time.monotonic()<deadline and not list(runtime.glob('sway-ipc.*.sock')):
   assert child.poll() is None,(home/'sway.log').read_text();time.sleep(.05)
  env['SWAYSOCK']=str(next(runtime.glob('sway-ipc.*.sock')))
  assert next(o for o in query('get_outputs') if o['name']=='HEADLESS-1')['scale']==1, 'legacy overrides remain usable without GUI files'
  # Native nwg-displays defaults, exactly as saved by its app-menu launcher.
  (config/'outputs').write_text('output HEADLESS-1 {\n mode 1280x720\n scale 2\n pos 20 30\n}\n')
  (config/'workspaces').write_text('workspace 7 output HEADLESS-2\n')
  result=json.loads(subprocess.check_output([str(P(sway).with_name('swaymsg')),'-r','reload'],env=env,text=True,timeout=5));assert result[0]['success'],result
  deadline=time.monotonic()+5
  while time.monotonic()<deadline:
   output=next(o for o in query('get_outputs') if o['name']=='HEADLESS-1')
   if output['scale']==2 and output['rect']['x']==20 and output['rect']['y']==30:break
   time.sleep(.05)
  assert output['scale']==2 and output['rect']['x']==20 and output['rect']['y']==30, output
  subprocess.run([str(P(sway).with_name('swaymsg')),'-q','focus output HEADLESS-1; workspace 7'],env=env,check=True)
  workspace=next(w for w in query('get_workspaces') if w['num']==7)
  assert workspace['output']=='HEADLESS-2', workspace
  assert (config/'outputs.conf').read_text()=='output HEADLESS-1 scale 1\n'
  print('PASS: private Sway applies saved native outputs/workspaces, GUI overrides legacy without modifying it')
 except Exception:
  log.flush();print(cfg.read_text());print((home/'sway.log').read_text(errors='replace'));raise
 finally:
  if child.poll() is None:os.killpg(child.pid,signal.SIGTERM);child.wait(timeout=5)
  log.close()
