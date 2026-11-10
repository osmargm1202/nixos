#!/usr/bin/env python3
"""Check desktop identity through a real, isolated GNOME Shell AppSystem."""
import json,os,pathlib,subprocess,sys,tempfile,time,signal,shutil
if not shutil.which("gnome-shell"):
 print("SKIP: GNOME Shell is required")
 raise SystemExit(0)
if len(sys.argv)==1:
 with tempfile.TemporaryDirectory(prefix='origin-gnome-') as temporary:
  h=pathlib.Path(temporary);(h/'runtime').mkdir(mode=0o700)
  env=dict(os.environ,HOME=str(h),XDG_RUNTIME_DIR=str(h/'runtime'),XDG_CONFIG_HOME=str(h/'config'),XDG_CACHE_HOME=str(h/'cache'),XDG_DATA_HOME=str(h/'data'),XDG_STATE_HOME=str(h/'state'),XDG_CURRENT_DESKTOP='GNOME',XDG_SESSION_TYPE='wayland',GNOME_SHELL_SESSION_MODE='user',LIBGL_ALWAYS_SOFTWARE='1',ORIGIN_PROBE_HOME=str(h))
  for k in ['DBUS_SESSION_BUS_ADDRESS','DISPLAY','WAYLAND_DISPLAY','WAYLAND_SOCKET','HYPRLAND_INSTANCE_SIGNATURE']:env.pop(k,None)
  result=subprocess.run(['dbus-run-session','--','python3',__file__,'--inside'],env=env)
  raise SystemExit(result.returncode)
h=pathlib.Path(os.environ['ORIGIN_PROBE_HOME']);profile=h/'profile';profile.mkdir();(profile/'Local State').write_text(json.dumps({'brave':{'origin':{'free_tier_accepted':True}}}))
apps=h/'data/applications';apps.mkdir(parents=True)
browser=os.environ.get('ORGM_TEST_ORIGIN') or shutil.which('brave-origin')
assert browser, 'Set ORGM_TEST_ORIGIN to the Origin executable'
for suffix in ['a','b']:
 identity='brave-example.com__'+suffix+'-Default'
 (apps/(identity+'.desktop')).write_text('[Desktop Entry]\nType=Application\nName=Origin fixture '+suffix+'\nIcon=utilities-terminal\nStartupWMClass='+identity+'\nExec='+browser+' --user-data-dir='+str(profile)+' --profile-directory=Default --ozone-platform=wayland --app=https://example.com/'+suffix+'\n')
ext=h/'data/gnome-shell/extensions/probe@origin.test';ext.mkdir(parents=True)
(ext/'metadata.json').write_text(json.dumps({'uuid':'probe@origin.test','name':'Origin fixture','description':'Private test','shell-version':['50']}))
(ext/'extension.js').write_text('''import GLib from 'gi://GLib';
import Shell from 'gi://Shell';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
export default class Probe extends Extension {
 enable() { this.timer=GLib.timeout_add(GLib.PRIORITY_DEFAULT,500,()=>{
 const apps=Shell.AppSystem.get_default().get_running().filter(a=>a.get_id().startsWith('brave-example.com__')).map(a=>({id:a.get_id(),windows:a.get_windows().length,pids:a.get_windows().map(w=>w.get_pid())}));
 GLib.file_set_contents(GLib.getenv('ORIGIN_PROBE_HOME')+'/result.json',JSON.stringify(apps));return GLib.SOURCE_CONTINUE;
 }); }
 disable() {if(this.timer)GLib.source_remove(this.timer);}
}''')
for args in [['org.gnome.shell','enabled-extensions',"['probe@origin.test']"],['org.gnome.shell','disable-user-extensions','false']]:subprocess.run(['gsettings','set',*args],check=True)
log=(h/'session.log').open('w');children=[]
def start(args):
 p=subprocess.Popen(args,stdout=log,stderr=log,start_new_session=True);children.append(p);return p
def wait(fn,label):
 for _ in range(160):
  try:
   value=fn()
   if value:return value
  except (FileNotFoundError,json.JSONDecodeError):pass
  time.sleep(.1)
 raise RuntimeError(label+'\n'+(h/'session.log').read_text()[-5000:])
try:
 start(['gnome-shell','--headless','--wayland','--no-x11','--virtual-monitor=1280x800','--wayland-display=wayland-origin-test'])
 wait(lambda:(h/'runtime/wayland-origin-test').exists(),'private Wayland socket')
 os.environ['WAYLAND_DISPLAY']='wayland-origin-test'
 wait(lambda:(h/'result.json').exists(),'isolated Shell probe extension')
 for suffix in ['a','b']:start([browser,'--user-data-dir='+str(profile),'--profile-directory=Default','--ozone-platform=wayland','--no-first-run','--app=https://example.com/'+suffix]);time.sleep(1)
 result=wait(lambda:(r if len(r)==2 and all(x['windows']==1 for x in r) else None) if (r:=json.loads((h/'result.json').read_text())) else None,'two separate GNOME applications')
 assert len({p for app in result for p in app['pids']})==1,result
 print('PASS: GNOME Shell associates each shared-process webapp with its own desktop application:',json.dumps(result),flush=True)
finally:
 for p in reversed(children):
  if p.poll() is None:os.killpg(p.pid,signal.SIGTERM)
 for p in reversed(children):
  try:p.wait(timeout=5)
  except subprocess.TimeoutExpired:os.killpg(p.pid,signal.SIGKILL)
 log.close()
