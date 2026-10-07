local upstream = assert(arg[1])
local bindings, scope = {}, "default"
local function dispatchers(path)
  return setmetatable({}, {
    __index = function(_, key) return dispatchers(path .. "." .. key) end,
    __call = function(_, ...) return { dispatcher = path, arguments = { ... } } end,
  })
end
hl = {
  dsp = dispatchers("dsp"),
  bind = function(chord, action, options)
    bindings[#bindings + 1] = { chord = chord, action = action, scope = scope, options = options }
  end,
  define_submap = function(name, fn)
    scope = name; fn(); scope = "default"
  end,
  on = function() end,
  window_rule = function() end,
  dispatch = function(action) hl.last_dispatch = action end,
}
local config = assert(os.getenv("XDG_CONFIG_HOME"))
package.path = config .. "/hypr/?.lua;" .. upstream .. "/ryoku/hyprland/?.lua;" .. package.path
require("modules.binds")
require("modules.ryoshot")
require("modules.resize")
require("modules.record")
local upstream_count = #bindings
assert(loadfile(config .. "/orgm-ryoku/user.lua"))()
local shortcuts = assert(package.loaded["orgm-ryoku.shortcuts"])
assert(shortcuts.normalize("SUPER + Next") == shortcuts.normalize("SUPER + Page_Down"))
assert(shortcuts.normalize("SUPER + Prior") == shortcuts.normalize("SUPER + Page_Up"))
assert(shortcuts.normalize("SUPER + quoteleft") == shortcuts.normalize("SUPER + grave"))
local keys, actions = {}, {}
for _, binding in ipairs(bindings) do
  if binding.scope == "default" then
    local normalized = shortcuts.normalize(binding.chord)
    assert(not keys[normalized], "shortcut collision: " .. binding.chord)
    keys[normalized] = true
    actions[normalized] = binding.action
  end
end
for _, binding in ipairs(shortcuts.personal) do
  assert(keys[shortcuts.normalize(binding[1])], "Osmarg lost " .. binding.original)
end
for _, binding in ipairs(shortcuts.relocated) do
  assert(keys[shortcuts.normalize(binding[2])], "Ryoku lost " .. binding[1])
  assert(not shortcuts.reserved[shortcuts.normalize(binding[2])])
  local function_key = binding[2]:match("%+ F(%d+)$")
  assert(not function_key or tonumber(function_key) <= 12, "unavailable function key: " .. binding[2])
end
local function action(chord)
  return assert(actions[shortcuts.normalize(chord)], "missing " .. chord)
end
local terminal = action("SUPER + Return")
assert(terminal.dispatcher == "dsp.exec_cmd" and terminal.arguments[1] == "ryoku-app terminal")
assert(action("SUPER + CTRL + Return").arguments[1] == "ryoku-app terminal -- tmux -u new-session -A -s main")
local launcher = action("SUPER + Space")
assert(launcher.dispatcher == "dsp.global" and launcher.arguments[1] == "ryoku:launcher")
local help = action("SUPER + slash")
assert(help.dispatcher == "dsp.exec_cmd" and help.arguments[1] == "ryoku-shell hub open keybinds")
local orgmai = action("SUPER + SHIFT + A")
assert(orgmai.dispatcher == "dsp.exec_cmd" and orgmai.arguments[1]:find("orgmai prev", 1, true))
local quicksettings = action("SUPER + ALT + Space")
assert(quicksettings.dispatcher == "dsp.global" and quicksettings.arguments[1] == "ryoku:quicksettings")
local clipboard = action("SUPER + V")
assert(clipboard.dispatcher == "dsp.global" and clipboard.arguments[1] == "ryoku:clipboard")
local windows = action("SUPER + CTRL + W")
assert(windows.dispatcher == "dsp.exec_cmd" and windows.arguments[1] == "windows-rdp toggle")
local volume = action("XF86AudioRaiseVolume")
assert(volume.dispatcher == "dsp.exec_cmd" and volume.arguments[1] == "ryoku-volume up")
local lock = action("SUPER + L")
assert(lock.dispatcher == "dsp.exec_cmd" and lock.arguments[1] == "ryoku-shell lock")
local focus_right = action("SUPER + Right")
assert(focus_right.dispatcher == "dsp.focus" and focus_right.arguments[1].direction == "right")
for _, key in ipairs({ "H", "J", "K" }) do
  assert(not keys[shortcuts.normalize("SUPER + " .. key)], "reserved key is not free: " .. key)
  assert(not keys[shortcuts.normalize("SUPER + CTRL + " .. key)], "legacy direction is still bound: " .. key)
end
local shot = action("Print")
assert(shot.dispatcher == "dsp.exec_cmd" and shot.arguments[1]:find("qs -c ryoshot", 1, true))
assert(action("CTRL + Print").arguments[1]:find("RYOSHOT_MODE=monitor", 1, true))
assert(action("SUPER + Print").arguments[1] == "ryoku-cmd-screenrecord")
assert(action("SUPER + SHIFT + Print").arguments[1] == "ryoku-shell menu screenshot")
assert(action("SUPER + C").arguments[1] == "ryoku:launcher")
assert(action("SUPER + 3").arguments[1]:find("ryoku-workspace focus 3", 1, true))
assert(action("ALT + Tab").arguments[1] == "ryoku:overview")
for _, binding in ipairs(bindings) do
  if type(binding.action) == "table" and binding.action.dispatcher == "dsp.exec_cmd" then
    local command = binding.action.arguments[1] or ""
    assert(not command:find("record_screen_", 1, true), command)
    assert(not command:find("swappy", 1, true), command)
    assert(not command:find("hypr-rofi-calc", 1, true), command)
    assert(not command:find("wlogout", 1, true), command)
  end
end
print(string.format("PASS: %d upstream bindings retained, %d Osmarg bindings preserved, %d Ryoku collisions relocated",
  upstream_count, #shortcuts.personal, #shortcuts.relocated))
