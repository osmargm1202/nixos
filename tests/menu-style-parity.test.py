#!/usr/bin/env python3
import json,os,shutil,subprocess,tempfile,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
COMMON=ROOT/'dotfiles/config/profiles/wayland/.local/bin/orgm-rofi'
class Menus(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup);self.home=Path(self.tmp.name)
  binary=self.home/'.local/bin';binary.mkdir(parents=True)
  self.log=self.home/'rofi.json'
  (binary/'rofi').write_text('#!/usr/bin/env python3\nimport json,os,sys\nfrom pathlib import Path\nPath(os.environ["ROFI_LOG"]).write_text(json.dumps(sys.argv[1:]))\nprint(os.environ.get("ROFI_REPLY",""))\nsys.exit(int(os.environ.get("ROFI_EXIT","0")))\n');(binary/'rofi').chmod(0o755)
  self.env=dict(os.environ,HOME=str(self.home),PATH=str(binary)+os.pathsep+os.environ['PATH'],XDG_CONFIG_HOME=str(self.home/'.config'),XDG_CACHE_HOME=str(self.home/'.cache'),XDG_STATE_HOME=str(self.home/'state'),ROFI_LOG=str(self.log),ORGM_ROFI=str(COMMON))
 def invoke(self,args):
  result=subprocess.run(args,env=self.env,capture_output=True,text=True)
  self.assertEqual(result.returncode,0,result.stderr)
  return json.loads(self.log.read_text())
 def test_launcher_and_dmenu_same_theme_and_palette_both_compositors(self):
  for comp in ('sway','hyprland'):
   self.env['XDG_CURRENT_DESKTOP']=comp
   base='hypr' if comp=='hyprland' else 'sway'
   lib=ROOT/f'dotfiles/config/profiles/{comp}/.local/bin/{base}-rofi-lib'
   launch=self.invoke(['bash','-c',f'. "$1"; {base}_rofi_drun','_',str(lib)])
   menu=self.invoke(['bash','-c',f'. "$1"; {base}_rofi_dmenu SSH','_',str(lib)])
   self.assertEqual(launch[launch.index('-theme')+1],menu[menu.index('-theme')+1])
   self.assertTrue(menu[menu.index('-theme')+1].endswith('sway-launcher.rasi'))
   style=menu[menu.index('-theme-str')+1]
   self.assertIn('#8ab4f8',style)
   self.assertIn('JetBrainsMono Nerd Font 12',style)
   self.assertNotIn('sway-menu.rasi',' '.join(menu))
 def test_all_effective_firefox_prompts_use_common_helper(self):
  self.assertTrue(COMMON.exists(),'missing shared launcher styling')
  for p in ROOT.glob('dotfiles/config/**/.local/bin/firefox-open-tab'):
   self.assertIn('orgm-rofi',p.read_text(),str(p))
 def test_tablet_targets_and_exit_status_are_preserved(self):
  self.env['XDG_CURRENT_DESKTOP']='sway';pref=self.home/'state/orgm-tablet/preferences.json';pref.parent.mkdir(parents=True);pref.write_text('{"mode":"on"}')
  args=self.invoke([str(COMMON),'-dmenu','-p','Literal $(touch /tmp/not-run)'])
  self.assertIn('Literal $(touch /tmp/not-run)',args)
  style=args[args.index('-theme-str')+1]
  self.assertIn('* { font: \"JetBrainsMono Nerd Font 18\";',style)
  self.assertIn('prompt { font: \"JetBrainsMono Nerd Font 18\";',style)
  self.env['ROFI_EXIT']='1'
  self.assertEqual(subprocess.run([str(COMMON),'-dmenu'],env=self.env,capture_output=True).returncode,1)
if __name__=='__main__':unittest.main()
