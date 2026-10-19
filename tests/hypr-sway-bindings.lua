-- Execute effective personal Lua modules; record the compositor boundary only.
local root = assert(arg[1])
package.path = root .. "/dotfiles/config/users/osmarg/profiles/hyprland/.config/hypr/?.lua;"
  .. root .. "/dotfiles/config/profiles/hyprland/.config/hypr/?.lua;" .. package.path
local function dispatcher()
  return setmetatable({}, {
    __index = function(t, k) local value = dispatcher(); rawset(t, k, value); return value end,
    __call = function(_, value) return type(value) == "string" and value or "" end,
  })
end
local bindings, startup = {}, {}
hl = {
  dsp = dispatcher(),
  bind = function(combo, command)
    assert(bindings[combo] == nil, "duplicate shortcut: " .. combo)
    bindings[combo] = command
  end,
  on = function(event, callback) if event == "hyprland.start" then callback() end end,
  exec_cmd = function(command) table.insert(startup, command) end,
}
require("lua.keybindings").setup(require("lua.programs"))
assert(bindings["ALT + Tab"] == "orgm-hyprland windows")
assert(bindings["ALT + SHIFT + Tab"] == "orgm-hyprland windows prev")
assert(bindings["SUPER + V"] == "orgm-hyprland clipboard")
assert(bindings["SUPER + L"] == "orgm-qylock lock")
assert(bindings["SUPER + ALT + Space"] == "orgm-hyprland control")
assert(bindings["SUPER + A"]:find("orgmai new", 1, true))
assert(bindings["SUPER + O"] == "hypr-obsidian-open-or-focus")
require("lua.autostart")
local supervisor = 0
for _, command in ipairs(startup) do
  if command == "orgm-hyprland-session" then supervisor = supervisor + 1 end
  assert(command ~= "hypridle", "idle must be session-owned")
  assert(not command:find("wl-paste", 1, true), "clipboard must be session-owned")
  assert(not command:find("hypr-nwg-dock", 1, true), "dock must be session-owned")
end
assert(supervisor == 1, "exactly one compositor supervisor")
print("PASS: effective personal keybindings and session-owned startup")
