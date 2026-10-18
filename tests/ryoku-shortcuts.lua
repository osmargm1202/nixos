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
  unbind = function(chord)
    for i = #bindings, 1, -1 do
      if bindings[i].scope == "default" and bindings[i].chord == chord then table.remove(bindings, i) end
    end
  end,
  define_submap = function(name, fn)
    scope = name; fn(); scope = "default"
  end,
  on = function() end,
  config = function() end,
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
require("settings")
assert(loadfile(config .. "/orgm-ryoku/user.lua"))()
local shortcuts = assert(package.loaded["orgm-ryoku.shortcuts"])
assert(shortcuts.normalize("SUPER + Next") == shortcuts.normalize("SUPER + Page_Down"))
assert(shortcuts.normalize("SUPER + Prior") == shortcuts.normalize("SUPER + Page_Up"))
assert(shortcuts.normalize("SUPER + quoteleft") == shortcuts.normalize("SUPER + grave"))
local keys, actions = {}, {}
for _, binding in ipairs(bindings) do
  if binding.scope == "default" then
    local normalized = shortcuts.normalize(binding.chord)
    if keys[normalized] then
      local previous = actions[normalized]
      error("shortcut collision: " .. binding.chord .. " previous=" ..
        tostring(type(previous) == "table" and previous.arguments[1] or previous) .. " next=" ..
        tostring(type(binding.action) == "table" and binding.action.arguments[1] or binding.action))
    end
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
local floating = action("SUPER + SHIFT + Space")
assert(floating.dispatcher == "dsp.window.float" and floating.arguments[1].action == "toggle")
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
local stash = action("SUPER + H")
assert(stash.dispatcher == "dsp.exec_cmd" and stash.arguments[1] == (os.getenv("RYOKU_EXPECT_STASH") or "ryoku-shell stash"))
local old_hide = action("SUPER + CTRL + ALT + SHIFT + H")
assert(old_hide.dispatcher == "dsp.exec_cmd" and old_hide.arguments[1]:find(" hide", 1, true))
if os.getenv("RYOKU_EXPECT_STASH") then
  assert(action("SUPER + K").arguments[1] == "personal-help")
  assert(action("SUPER + CTRL + ALT + SHIFT + K").arguments[1] == "personal-other")
end
local native_help = action(os.getenv("RYOKU_EXPECT_HELP_CHORD") or "SUPER + K")
assert(native_help.dispatcher == "dsp.exec_cmd" and native_help.arguments[1]:find("qs -c keys", 1, true))
for _, key in ipairs({ "J" }) do
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
