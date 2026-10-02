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
local keys, actions = {}, {}
for _, binding in ipairs(bindings) do
  if binding.scope == "default" then
    local normalized = shortcuts.normalize(binding.chord)
    assert(not keys[normalized], "shortcut collision: " .. binding.chord)
    keys[normalized] = true
    actions[normalized] = binding.action
  end
end
assert(#shortcuts.personal > 100, "personal bindings missing")
assert(#shortcuts.relocated > 20, "Ryoku bindings did not move")
for _, binding in ipairs(shortcuts.personal) do
  assert(keys[shortcuts.normalize(binding[1])], "Osmarg lost " .. binding[1])
end
for _, binding in ipairs(shortcuts.relocated) do
  assert(keys[shortcuts.normalize(binding[2])], "Ryoku lost " .. binding[1])
  assert(not shortcuts.reserved[shortcuts.normalize(binding[2])])
end
assert(actions["SUPER + SPACE"].dispatcher == "dsp.global")
assert(actions["SUPER + SPACE"].arguments[1] == "ryoku:launcher")
assert(actions["SUPER + ALT + SPACE"].arguments[1] == "ryoku:quicksettings")
assert(actions["SUPER + V"].arguments[1] == "ryoku:clipboard")
assert(actions["SUPER + CTRL + W"].arguments[1] == "windows-rdp toggle")
assert(actions["XF86AUDIORAISEVOLUME"].arguments[1] == "ryoku-volume up")
actions["ALT + TAB"]()
assert(hl.last_dispatch.arguments[1] == "ryoku:overview")
print(string.format("PASS: %d upstream bindings retained, %d Osmarg bindings preserved, %d Ryoku collisions relocated",
  upstream_count, #shortcuts.personal, #shortcuts.relocated))
