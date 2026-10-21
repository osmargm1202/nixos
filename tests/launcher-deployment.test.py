#!/usr/bin/env python3
"""Actual orgm-dot layers must deliver Win+Space's complete execution chain."""
import json,os,subprocess,tempfile,unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]

class LauncherDeployment(unittest.TestCase):
 def test_selected_programs_without_rofi_still_deploy_working_launcher(self):
  for host,user,profile,prefix in [('orgm','osmarg','hyprland','hypr'),('envy','osmarg','sway','sway'),('jarq','jarq','sway','sway')]:
   with self.subTest(host=host),tempfile.TemporaryDirectory(prefix='launcher-deploy-') as tmp:
    home=Path(tmp);state=home/'state';binary=home/'bin';binary.mkdir()
    context=home/'context.json'
    context.write_text(json.dumps(dict(repository=str(ROOT),host=host,user=user,profile=profile,programs=['shell','webapps'])))
    env=dict(os.environ,HOME=tmp,XDG_CONFIG_HOME=str(home/'.config'),XDG_STATE_HOME=str(state),XDG_CURRENT_DESKTOP=profile,PATH=str(binary)+os.pathsep+os.environ['PATH'])
    for key in ('ORGM_ROFI','SWAY_ROFI_LIB','HYPR_ROFI_LIB','HYPR_ROFI_ENV','SWAY_ROFI_ENV','ORGM_DESKTOP_COMPOSITOR'):env.pop(key,None)
    for app in ('rofi','wayland-tools','hyprland' if profile=='hyprland' else 'sway-tools'):
     p=subprocess.run(['orgm-dot','--context',str(context),'--repo',str(ROOT),'--home',tmp,'--state',str(state/'dot'),'pull',app],env=env,capture_output=True,text=True)
     self.assertEqual(p.returncode,0,p.stderr)
    helper=home/'.local/bin/orgm-rofi'
    self.assertTrue(helper.is_file(),'orgm-dot omitted the shared launcher helper for '+host)
    self.assertTrue(os.access(helper,os.X_OK),'deployed helper must be executable')
    capture=home/'rofi-call.json'
    rofi=binary/'rofi'
    rofi.write_text('#!/usr/bin/env python3\nimport json,sys\nfrom pathlib import Path\nPath('+repr(str(capture))+').write_text(json.dumps(sys.argv[1:]))\n')
    rofi.chmod(0o755)
    env['PATH']=str(binary)+os.pathsep+str(home/'.local/bin')+os.pathsep+os.environ['PATH']
    p=subprocess.run([str(home/f'.local/bin/{prefix}-app-launcher')],env=env,capture_output=True,text=True)
    self.assertEqual(p.returncode,0,p.stderr)
    args=json.loads(capture.read_text())
    self.assertEqual(args[args.index('-show')+1],'drun')
    self.assertEqual(args[args.index('-theme')+1],str(home/'.config/rofi-sway/sway-launcher.rasi'))

if __name__=='__main__':unittest.main()
