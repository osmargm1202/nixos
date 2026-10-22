#!/usr/bin/env python3
"""Real Lua rules, opt-in performance matrix and transactional helper contracts."""
import glob,itertools,json,os,re,runpy,shutil,subprocess,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[1]
HELPER=ROOT/'dotfiles/config/users/osmarg/profiles/hyprland/.local/bin/hypr-game-mode'
LUA=shutil.which('lua') or glob.glob('/nix/store/*-lua-5.*/bin/lua')[0]
RECORDER=r'''
local root=arg[1]
package.path=root.."/dotfiles/config/profiles/hyprland/.config/hypr/?.lua;"..package.path
local function json(v)
 if type(v)=="string"then return '"'..v:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n')..'"' end
 if type(v)=="boolean" or type(v)=="number"then return tostring(v) end
 local values={};local array=#v>0
 for k,item in pairs(v)do values[#values+1]=(array and "" or json(k)..":")..json(item)end
 return (array and "[" or "{")..table.concat(values,",")..(array and "]" or "}")
end
local configs,rules={},{}
hl={config=function(v)for k,value in pairs(v)do configs[k]=value end end,
 window_rule=function(v)rules[#rules+1]=v end,curve=function()end,animation=function()end}
require("lua.look-and-feel");require("lua.window-rules")
print(json({config=configs,rules=rules,preferences=require("lua.game-mode").preferences()}))
'''
class Gaming(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup);self.home=Path(self.tmp.name)
  self.state=self.home/'state/hypr';self.state.mkdir(parents=True)
  self.binary=self.home/'bin';self.binary.mkdir();self.calls=self.home/'calls'
  self.fail=self.home/'fail';self.rows=self.home/'rows';self.queue=self.home/'queue'
  self.env=dict(os.environ,HOME=str(self.home),XDG_STATE_HOME=str(self.home/'state'),XDG_CONFIG_HOME=str(self.home/'config'),XDG_CACHE_HOME=str(self.home/'cache'),PATH=str(self.binary)+os.pathsep+os.environ['PATH'],CALLS=str(self.calls),FAIL=str(self.fail),QUEUE=str(self.queue),ROWS=str(self.rows))
  stubs={'hyprctl':'echo hyprctl "$*" >>"$CALLS"; if [ -e "$FAIL" ]; then rm "$FAIL";exit 1;fi',
   'hypr-wallpaper':'echo wallpaper "$*" >>"$CALLS"','notify-send':'exit 0','pgrep':'exit 0',
   'orgm-rofi':'cat >>"$ROWS"; IFS= read -r next <"$QUEUE" || exit 1; tail -n +2 "$QUEUE" >"$QUEUE.tmp";mv "$QUEUE.tmp" "$QUEUE"; printf "%s\n" "$next"'}
  for name,body in stubs.items():
   p=self.binary/name;p.write_text('#!/usr/bin/env bash\n'+body+'\n');p.chmod(0o755)
  self.env.update(HYPR_WALLPAPER_BIN=str(self.binary/'hypr-wallpaper'),ORGM_ROFI=str(self.binary/'orgm-rofi'))
 def call(self,*args,ok=True):
  p=subprocess.run([str(HELPER),*args],env=self.env,capture_output=True,text=True,timeout=8)
  if ok:self.assertEqual(p.returncode,0,p.stderr)
  return p
 def options(self):return json.loads(self.call('options').stdout)
 def record(self,mode,vrr,tearing):
  for name,value in [('game-mode',mode),('game-vrr',vrr),('game-tearing',tearing)]:
   (self.state/name).write_text('activated\n' if value else 'deactivated\n')
  script=self.home/'record.lua';script.write_text(RECORDER)
  return json.loads(subprocess.check_output([LUA,str(script),str(ROOT)],env=self.env,text=True))
 def effects(self,data,cls,fullscreen):
  props={'class':cls,'title':'','modal':False,'fullscreen':fullscreen};effects={}
  for rule in data['rules']:
   if all(props.get(k)==v if isinstance(v,bool) else re.fullmatch(v,str(props.get(k,''))) is not None for k,v in rule['match'].items()):
    effects.update({k:v for k,v in rule.items() if k not in ('match','name')})
  return effects
 def test_policy_matrix_and_game_identity(self):
  for mode,vrr,tearing in itertools.product((False,True),repeat=3):
   with self.subTest(mode=mode,vrr=vrr,tearing=tearing):
    d=self.record(mode,vrr,tearing)
    self.assertEqual(d['preferences'],dict(vrr=vrr,tearing=tearing))
    self.assertEqual(d['config']['general']['layout'],'scrolling')
    self.assertIs(d['config']['general']['allow_tearing'],mode and tearing)
    self.assertEqual(d['config'].get('misc',{}).get('vrr',0),2 if mode and vrr else 0)
    self.assertIsNot(d['config'].get('misc',{}).get('focus_on_activate'),True)
    for cls in ('dota2','steam_app_570','steam_app_123','gamescope','EtG.x86_64'):
     for full in (False,True):
      e=self.effects(d,cls,full)
      self.assertIs(e.get('focus_on_activate'),True,(cls,e))
      self.assertEqual(bool(e.get('render_unfocused')),mode and full,(cls,e))
      self.assertEqual(bool(e.get('immediate')),mode and tearing and full,(cls,e))
    for cls in ('steam','steamwebhelper','firefox','kitty','steam_app_bad','not-dota2'):
     e=self.effects(d,cls,True)
     for flag in ('focus_on_activate','render_unfocused','immediate'):self.assertFalse(e.get(flag,False),(cls,flag,e))
 def test_preferences_default_off_and_persist_without_enabling_mode(self):
  self.assertEqual(self.options(),dict(vrr=False,tearing=False))
  self.call('vrr','on');self.assertEqual(self.options(),dict(vrr=True,tearing=False))
  self.assertEqual(self.call('status').stdout.strip(),'deactivated')
  self.assertFalse(self.calls.exists(),'prefs while off must not reload or change wallpaper')
  self.call('on');self.call('tearing','on');self.call('off')
  self.assertEqual(self.options(),dict(vrr=True,tearing=True))
  self.assertEqual(self.calls.read_text().count('wallpaper hide'),1)
  self.assertEqual(self.calls.read_text().count('wallpaper restore'),1)
 def test_reload_failure_rolls_back_option_but_not_mode(self):
  self.call('on');self.fail.touch()
  self.assertNotEqual(self.call('tearing','on',ok=False).returncode,0)
  self.assertEqual(self.options(),dict(vrr=False,tearing=False))
  self.assertEqual(self.call('status').stdout.strip(),'activated')
 def test_invalid_arguments_and_corrupt_flags_fail_closed(self):
  for args in [('vrr','bad'),('tearing','on;touch bad')]:self.assertEqual(self.call(*args,ok=False).returncode,64)
  (self.state/'game-vrr').write_text('garbage\n')
  self.assertEqual(self.options(),dict(vrr=False,tearing=False))
 def test_atomic_write_and_lock_failures_propagate_through_settings(self):
  for tool in ('mktemp','mv','flock'):
   with self.subTest(tool=tool):
    stub=self.binary/tool;stub.write_text('#!/bin/sh\nexit 1\n');stub.chmod(0o755)
    try:
     self.queue.write_text('0\n2\n')
     self.assertNotEqual(self.call('settings',ok=False).returncode,0)
     self.assertEqual(self.options(),dict(vrr=False,tearing=False))
     self.assertNotEqual(self.call('vrr','on',ok=False).returncode,0)
     self.assertEqual(self.options(),dict(vrr=False,tearing=False))
    finally:stub.unlink()
 def test_multiline_malformed_preferences_fail_closed_in_lua_and_cli(self):
  for name in ('game-vrr','game-tearing'):(self.state/name).write_text('activated\ngarbage\n')
  self.assertEqual(self.options(),dict(vrr=False,tearing=False))
  script=self.home/'record.lua';script.write_text(RECORDER)
  d=json.loads(subprocess.check_output([LUA,str(script),str(ROOT)],env=self.env,text=True))
  self.assertEqual(d['preferences'],dict(vrr=False,tearing=False))
 def test_nonregular_preference_is_disabled_without_lua_error(self):
  (self.state/'game-vrr').mkdir()
  self.assertEqual(self.options(),dict(vrr=False,tearing=False))
  script=self.home/'record.lua';script.write_text(RECORDER)
  d=json.loads(subprocess.check_output([LUA,str(script),str(ROOT)],env=self.env,text=True))
  self.assertEqual(d['preferences'],dict(vrr=False,tearing=False))
 def test_settings_menu_toggles_preferences_through_shared_rofi(self):
  self.queue.write_text('0\n1\n2\n');self.call('settings')
  self.assertEqual(self.options(),dict(vrr=True,tearing=True))
  self.assertEqual(self.call('status').stdout.strip(),'deactivated')
  self.assertIn('VRR',self.rows.read_text());self.assertIn('Tearing',self.rows.read_text())
 def test_control_center_exposes_supported_settings_only(self):
  m=runpy.run_path(str(ROOT/'dotfiles/config/profiles/sway/.local/bin/orgm-sway-desktop'));g=m['control_commands'].__globals__
  for comp in ('sway','hyprland'):
   with patch.dict(g,SWAY=dict(g['SWAY'],compositor=comp)),patch.object(g['shutil'],'which',return_value='/fixture/tool'):
    commands=m['control_commands']();ids={c['id'] for c in m['control_controls']()}
    self.assertEqual('gaming-options' in ids,comp=='hyprland')
    if comp=='hyprland':self.assertEqual(commands['gaming-options'],['hypr-game-mode','settings'])
if __name__=='__main__':unittest.main()
