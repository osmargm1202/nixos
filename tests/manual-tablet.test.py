#!/usr/bin/env python3
"""Manual tablet policy, immutable normal profile and current-session boundaries."""
import copy,importlib.util,json,os,subprocess,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[1]
class Tablet(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  path=ROOT/'dotfiles/config/profiles/wayland/.local/lib/orgm-wayland/tablet.py'
  assert path.exists(),'manual tablet policy missing'
  spec=importlib.util.spec_from_file_location('tablet',path);cls.m=importlib.util.module_from_spec(spec);spec.loader.exec_module(cls.m)
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
  self.home=Path(self.tmp.name)
  self.env=patch.dict(os.environ,HOME=str(self.home),XDG_STATE_HOME=str(self.home/'state'),XDG_CACHE_HOME=str(self.home/'cache'),WAYLAND_DISPLAY='private-wayland',SWAYSOCK=str(self.home/'sway.sock'),HYPRLAND_INSTANCE_SIGNATURE='',ORGM_DESKTOP_COMPOSITOR='sway')
  self.env.start();self.addCleanup(self.env.stop)
 def test_default_and_old_auto_are_off_without_hardware_reads(self):
  self.assertEqual(self.m.load_policy()['mode'],'off')
  p=self.home/'state/orgm-tablet/preferences.json';p.parent.mkdir(parents=True);p.write_text('{"mode":"auto"}')
  self.assertEqual(self.m.load_policy()['mode'],'off')
  with patch.object(self.m,'keyboard_state',return_value={}):
   s=self.m.state();self.assertFalse(s['active']);self.assertEqual(s['source'],'manual')
 def test_auto_is_rejected_and_mode_is_persistent(self):
  with self.assertRaises(ValueError):self.m.set_policy('auto')
  self.m.set_policy('on');self.assertEqual(self.m.load_policy()['mode'],'on')
  self.m.set_policy('toggle');self.assertEqual(self.m.load_policy()['mode'],'off')
 def test_tablet_profile_reduces_controls_and_enlarges_touch_targets(self):
  original={'height':30,'modules-left':['custom/launcher','battery','pulseaudio'],'modules-right':['network','custom/control','tray'],'modules-center':['clock'],'battery':{'format':'battery'},'custom/control':{'on-click':'old control'},'output':['HEADLESS-1']}
  saved=copy.deepcopy(original)
  for comp in ('sway','hyprland'):
   bar=self.m.bar_profile(original,comp,True)
   self.assertEqual(bar['height'],52);self.assertEqual(bar['modules-left'],['battery'])
   self.assertEqual(bar['modules-center'],['clock']);self.assertEqual(bar['modules-right'],['custom/control'])
   self.assertEqual(bar['output'],['HEADLESS-1'])
   self.assertEqual(bar['custom/control']['on-click'],'orgm-'+comp+' control')
   self.assertEqual(self.m.bar_profile(original,comp,False),saved)
  self.assertEqual(original,saved)
 def test_mode_change_restarts_only_current_session_services(self):
  manager='WAYLAND_DISPLAY=private-wayland\nSWAYSOCK='+str(self.home/'sway.sock')+'\n'
  calls=[]
  def run(args,**kwargs):
   calls.append(args)
   return subprocess.CompletedProcess(args,0,stdout=manager if 'show-environment' in args else '',stderr='')
  with patch.object(self.m.subprocess,'run',side_effect=run):self.m.apply_profile()
  self.assertIn(['systemctl','--user','restart','orgm-sway-waybar.service','orgm-sway-dock.service'],calls)
  self.assertFalse(any('idle' in ' '.join(c) or 'hyprland' in ' '.join(c) for c in calls))
 def test_other_display_is_never_restarted(self):
  with patch.object(self.m.subprocess,'run',return_value=subprocess.CompletedProcess([],0,stdout='WAYLAND_DISPLAY=another-display\nSWAYSOCK=/other\n',stderr='')) as run:
   with self.assertRaises(RuntimeError):self.m.apply_profile()
   self.assertFalse(any('restart' in call.args[0] for call in run.call_args_list))
 def test_legacy_daemon_does_not_start_squeekboard_or_watch_sensors(self):
  with patch.object(self.m.subprocess,'run') as run:self.m.main(['daemon'])
  run.assert_not_called()
 def test_bar_generation_preserves_jsonc_urls(self):
  source=self.home/'bar.jsonc';source.write_text('{/* comment */"clock":{"format":"http://valid"},"modules-left":[],}')
  self.assertEqual(self.m.bar_config(source,'sway'),str(source))
  self.m.set_policy('on')
  result=Path(self.m.bar_config(source,'sway'))
  self.assertEqual(json.loads(result.read_text())['clock']['format'],'http://valid')
  self.assertIn('/* comment */',source.read_text())
 def test_dock_profile_has_only_three_large_actions_and_no_pin_mutation(self):
  ui=ROOT/'dotfiles/config/profiles/wayland/.config/quickshell/orgm-tablet-dock/shell.qml'
  self.assertTrue(ui.exists(),'tablet dock missing')
  text=ui.read_text()
  for action in ('launcher','windows','keyboard'):self.assertIn('"'+action+'"',text)
  self.assertNotIn('pinned',text)
  self.assertTrue((ROOT/'dotfiles/config/profiles/wayland/.local/bin/orgm-session-dock').is_file())
 def test_reduced_bar_retains_hidden_functional_inhibitor(self):
  source={'idle_inhibitor':{'start-activated':True,'format':'coffee'}}
  profile=self.m.bar_profile(source,'sway',True)
  modules=sum((profile.get(k,[]) for k in ('modules-left','modules-center','modules-right')),[])
  self.assertIn('idle_inhibitor',modules)
  self.assertTrue(profile['idle_inhibitor']['start-activated'])
  self.assertEqual(profile['idle_inhibitor']['format'],'')
 def test_symlink_preferences_are_rejected(self):
  directory=self.home/'state/orgm-tablet';directory.mkdir(parents=True)
  outside=self.home/'outside';outside.write_text('private')
  (directory/'preferences.json').symlink_to(outside)
  with self.assertRaises(ValueError):self.m.set_policy('on')
  self.assertEqual(outside.read_text(),'private')
if __name__=='__main__':unittest.main()
