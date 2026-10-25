#!/usr/bin/env python3
import json,runpy,unittest
from pathlib import Path
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[1]
M=runpy.run_path(str(ROOT/'dotfiles/config/profiles/sway/.local/bin/orgm-sway-desktop'));G=M['main'].__globals__
class Center(unittest.TestCase):
 def test_complete_touch_catalog_both_compositors(self):
  for comp in ('sway','hyprland'):
   with patch.dict(G,SWAY=dict(G['SWAY'],compositor=comp)),patch.object(G['shutil'],'which',return_value='/fixture/tool'):
    controls=M['control_controls']();ids={c['id'] for c in controls}
    self.assertTrue({'tablet','keyboard','windows','apps','audio','advanced-audio','terminal-mixer','clipboard','wifi','bluetooth','notifications','dnd','gaming','caffeine','profiles','wallpaper','random-wallpaper','appearance','themes','widgets','power','displays','files','accounts','monitor','help','layout','scratchpad','previous','play-pause','next','power-saver','balanced','performance'}<=ids,ids)
    self.assertTrue({'workspace-'+str(i) for i in range(1,11)}<=ids)
    self.assertTrue(all(isinstance(c['available'],bool) for c in controls))
 def test_manual_tablet_and_shared_keyboard_dispatch_only(self):
  calls=[]
  with patch.dict(G,control_state=lambda:{},run=lambda *args,**kw:calls.append(args)):
   M['control_action']('tablet','toggle');M['control_action']('keyboard','toggle')
   self.assertEqual(calls,[('orgm-tablet','mode','toggle'),('orgm-osk','toggle')])
   for a,v in (('tablet','auto'),('keyboard','auto'),('workspace','1;exec touch /tmp/unsafe'),('media','stop;bad'),('profile','bad')):
    with self.assertRaises(ValueError):M['control_action'](a,v)
   self.assertEqual(len(calls),2)
 def test_native_compositor_workspace_and_scratchpad_commands(self):
  for comp in ('sway','hyprland'):
   calls=[]
   with patch.dict(G,SWAY=dict(G['SWAY'],compositor=comp),control_state=lambda:{},run=lambda *a,**kw:calls.append(a)):
    M['control_action']('workspace','3');M['control_action']('scratchpad');M['control_action']('layout')
   if comp=='sway':self.assertEqual(calls[0],('swaymsg','workspace number 3'))
   else:self.assertEqual(calls[0],('hyprctl','dispatch','hl.dsp.focus({workspace="3"})'))
   self.assertEqual(calls[2][0],'swaymsg' if comp=='sway' else 'hyprctl')
 def test_network_and_bluetooth_use_installed_graphical_managers(self):
  for comp in ('sway','hyprland'):
   with patch.dict(G,SWAY=dict(G['SWAY'],compositor=comp)):
    commands=M['control_commands']()
    self.assertEqual(commands['advanced-audio'],['pavucontrol'])
    self.assertEqual(commands['terminal-mixer'],['kitty','-e','pulsemixer'])
    self.assertEqual(commands['wifi'],['nm-connection-editor'])
    self.assertEqual(commands['bluetooth'],['blueman-manager'])
    self.assertEqual(commands['apps'],[comp.removesuffix('land')+'-app-launcher'])
 def test_effective_waybar_secondary_audio_actions_have_touch_equivalents(self):
  sources=[ROOT/'dotfiles/config/profiles/sway/.config/waybar/config',ROOT/'dotfiles/config/users/osmarg/profiles/hyprland/.config/waybar-hypr/config']
  for source in sources:
   bar=json.loads(source.read_text())
   secondary=[v for module in bar.values() if isinstance(module,dict) for k,v in module.items() if k in ('on-click-right','on-click-middle') and isinstance(v,str)]
   commands=list(M['control_commands']().values())
   for name in ('pavucontrol','pulsemixer'):
    self.assertTrue(any(name in c for c in secondary),'fixture must contain '+name)
    self.assertTrue(any(name in c for c in commands),'missing touch equivalent '+name)
 def test_sway_display_editor_uses_native_files_included_by_sway(self):
  with patch.dict(G,SWAY=dict(G['SWAY'],compositor='sway')):
   self.assertEqual(M['control_commands']()['displays'],['nwg-displays','-n','10'])
  config=(ROOT/'dotfiles/config/profiles/sway/.config/sway/config').read_text().splitlines()
  for name in ('outputs','workspaces'):
   self.assertIn('include ~/.config/sway/'+name,config)
   self.assertLess(config.index('include ~/.config/sway/'+name+'.conf'),config.index('include ~/.config/sway/'+name))
 def test_unrecognized_choice_is_rejected(self):
  with self.assertRaises(ValueError):M['control_choice']('arbitrary command')
if __name__=='__main__':unittest.main()
