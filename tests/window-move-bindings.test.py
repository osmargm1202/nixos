#!/usr/bin/env python3
"""Execute both Hyprland layers and verify Sway's four-direction movement."""
import glob, os, shutil, subprocess, tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
LUA=os.environ.get('ORGM_TEST_LUA') or shutil.which('lua') or glob.glob('/nix/store/*-lua-5.*/bin/lua')[0]
with tempfile.TemporaryDirectory(prefix='move-binds-') as tmp:
 script=Path(tmp)/'verify.lua'
 script.write_text(r'''
local root=arg[1]
package.path=root.."/dotfiles/config/profiles/hyprland/.config/hypr/?.lua;"..package.path
local function dispatcher(path)
 return setmetatable({}, {__index=function(_,k)return dispatcher(path.."."..k)end,
  __call=function(_,args)return {path=path,args=args}end})
end
for _,profile in ipairs({"profiles/hyprland","users/osmarg/profiles/hyprland"})do
 local binds={}
 hl={dsp=dispatcher("hl.dsp"),bind=function(key,cmd,opts)
  assert(not binds[key],"duplicate "..key);binds[key]={cmd=cmd,opts=opts or {}}
 end}
 dofile(root.."/dotfiles/config/"..profile.."/.config/hypr/lua/keybindings.lua").setup({terminal="kitty",fileManager="nautilus"})
 for key,dir in pairs({left="l",right="r",up="u",down="d"})do
  for _,modifier in ipairs({"SHIFT","CTRL"})do
   local combo="SUPER + "..modifier.." + "..key
   local b=assert(binds[combo],profile..": missing "..combo)
   assert(b.cmd.path=="hl.dsp.window.move" and b.cmd.args.direction==dir,combo.." must move, not focus or change workspace")
  end
  assert(binds["SUPER + "..key].cmd.path=="hl.dsp.focus","plain arrows retain focus")
 end
 assert(binds["SUPER + R"].cmd.args=="colresize +conf","keep scrolling width cycle")
end
''')
 subprocess.run([LUA,str(script),str(ROOT)],check=True)
sway=(ROOT/'dotfiles/config/profiles/sway/.config/sway/config').read_text().splitlines()
for key,direction in [('Left','left'),('Right','right'),('Up','up'),('Down','down')]:
 for modifier in ('Shift','Ctrl'):
  matches=[line for line in sway if line.startswith('bindsym $mod+'+modifier+'+'+key+' ')]
  assert matches==['bindsym $mod+'+modifier+'+'+key+' move '+direction],matches
 assert 'bindsym $mod+'+key+' focus '+direction in sway
print('PASS: both Hyprland layers and Sway move in four directions; Ctrl and focus preserved')
