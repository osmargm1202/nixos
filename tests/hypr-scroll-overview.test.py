#!/usr/bin/env python3
"""Execute both real binding profiles and native plugin registration boundaries."""
import glob
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
LUA = os.environ.get('ORGM_TEST_LUA') or shutil.which('lua') or glob.glob('/nix/store/*-lua-5.*/bin/lua')[0]
with tempfile.TemporaryDirectory(prefix='scrolloverview-') as tmp:
    home = Path(tmp)
    plugin = home/'orgm-hyprland-tools/scrolloverview/lib/libscrolloverview.so'
    plugin.parent.mkdir(parents=True)
    plugin.write_bytes(b'test fixture; loader boundary mocked, no dlopen')
    recorder = home/'test.lua'
    recorder.write_text(r'''
local root, state = arg[1], arg[2]
package.path = root .. "/dotfiles/config/profiles/hyprland/.config/hypr/?.lua;" .. package.path
local function dispatcher(path)
  return setmetatable({}, {
    __index = function(_, key) return dispatcher(path .. "." .. key) end,
    __call = function(_, args) return {path=path,args=args} end,
  })
end
for _, profile in ipairs({"profiles/hyprland", "users/osmarg/profiles/hyprland"}) do
  local bindings, commands, toggles = {}, {}, 0
  hl={dsp=dispatcher("hl.dsp"), bind=function(k,fn) bindings[k]=fn end,
      exec_cmd=function(cmd) table.insert(commands,cmd) end,
      plugin={scrolloverview={overview=function(mode) assert(mode=="toggle"); toggles=toggles+1 end}}}
  dofile(root.."/dotfiles/config/"..profile.."/.config/hypr/lua/keybindings.lua").setup({terminal="kitty",fileManager="nautilus"})
  assert(type(bindings["ALT + Tab"])=="function", profile..": Alt+Tab bypasses ScrollOverview")
  bindings["ALT + Tab"](); bindings["ALT + SHIFT + Tab"]()
  assert(toggles==2 and #commands==0, "plugin must take precedence over Quickshell")
  -- Newer plugin dispatch factories return a callback outside a keybind context.
  hl.plugin.scrolloverview.overview=function(mode)
    assert(mode=="toggle"); return function() toggles=toggles+1 end
  end
  bindings["ALT + Tab"](); assert(toggles==3, "must execute a returned native dispatcher")
  hl.plugin.scrolloverview=nil
  bindings["ALT + Tab"](); bindings["ALT + SHIFT + Tab"]()
  assert(commands[1]=="orgm-hyprland windows" and commands[2]=="orgm-hyprland windows prev")
  hl.plugin.scrolloverview={overview=function() error("hook initialization failed") end}
  bindings["ALT + Tab"](); assert(commands[3]=="orgm-hyprland windows", "failed plugin must fall back")
end

-- Only /etc existence needs a mock: the test must not write system paths.
local real_open, system_exists = io.open, false
io.open=function(path, mode)
  if path=="/etc/scrolloverview.so" then
    return system_exists and real_open(state.."/orgm-hyprland-tools/scrolloverview/lib/libscrolloverview.so", mode) or nil
  end
  return real_open(path,mode)
end
local calls={}
hl={plugin={load=function(path) table.insert(calls,path) end}}
local module=dofile(root.."/dotfiles/config/profiles/hyprland/.config/hypr/lua/overview.lua")
local fallback=state.."/orgm-hyprland-tools/scrolloverview/lib/libscrolloverview.so"
assert(module.register()==fallback and calls[1]==fallback)
module.register(); assert(#calls==1, "same config must not register duplicate loads")
system_exists=true; calls={}
module=dofile(root.."/dotfiles/config/profiles/hyprland/.config/hypr/lua/overview.lua")
assert(module.register()=="/etc/scrolloverview.so" and calls[1]=="/etc/scrolloverview.so", "system plugin must take precedence")
system_exists=false; os.remove(fallback); calls={}
module=dofile(root.."/dotfiles/config/profiles/hyprland/.config/hypr/lua/overview.lua")
assert(module.register()==nil and #calls==0, "missing plugin must not break startup")
io.open=real_open
print("PASS: both profiles prefer ScrollOverview, safe fallback and idempotent declarative loading")
''')
    subprocess.run([LUA,str(recorder),str(ROOT),tmp],env=dict(os.environ,XDG_STATE_HOME=tmp),check=True)
