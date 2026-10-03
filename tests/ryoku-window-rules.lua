local config = assert(os.getenv("XDG_CONFIG_HOME"))
local callbacks, dispatched, existing = {}, {}, {}
hl = {
  window_rule = function() end,
  on = function(event, callback) callbacks[event] = callback end,
  get_windows = function() return existing end,
  dispatch = function(action) dispatched[#dispatched + 1] = action end,
  dsp = { window = {} },
}
for _, name in ipairs({ "float", "resize", "center" }) do
  hl.dsp.window[name] = function(options) return { name = name, options = options } end
end
assert(loadfile(config .. "/orgm-ryoku/window-rules.lua"))().setup()
local title = "Extension: (Bitwarden Password Manager) - Bitwarden — Mozilla Firefox"
local function window(id, window_title)
  return {
    stable_id = id, class = "firefox", title = window_title, mapped = true,
    floating = false, monitor = { width = 1920, height = 1080, scale = 1, transform = 0 },
  }
end
local function placed(target, first, width, height)
  assert(dispatched[first].name == "float" and dispatched[first].options.action == "set")
  local resize = dispatched[first + 1]
  assert(resize.name == "resize" and resize.options.relative == false)
  assert(resize.options.x == width and resize.options.y == height)
  assert(dispatched[first + 2].name == "center")
  for i = first, first + 2 do
    assert(dispatched[i].options.window == target, "acted on focused window instead of extension")
  end
end

local login = window(1, "Mozilla Firefox")
callbacks["window.open"](login)
assert(#dispatched == 0)
login.title = title
callbacks["window.title"](login)
placed(login, 1, 480, 680)
callbacks["window.title"](login)
callbacks["window.open"](login)
assert(#dispatched == 3, "repeated titles must not override manual placement")

for i, other_title in ipairs({ "Bitwarden", "Bitwarden — Mozilla Firefox", "Bitwarden documentation — Mozilla Firefox" }) do
  callbacks["window.title"](window(10 + i, other_title))
end
local unrelated = window(20, title)
unrelated.class = "kitty"
callbacks["window.title"](unrelated)
callbacks["window.title"](nil)
local unmapped = window(21, title)
unmapped.mapped = false
callbacks["window.title"](unmapped)
assert(#dispatched == 3, "matched a browser tab or an unrelated/unmapped client")

local small = window(30, title)
small.monitor = { width = 500, height = 600, scale = 1, transform = 0 }
callbacks["window.open"](small)
placed(small, 4, 460, 528)

local waiting = window(31, title)
waiting.monitor = nil
callbacks["window.title"](waiting)
assert(#dispatched == 6)
waiting.monitor = { width = 1920, height = 1080, scale = 1, transform = 0 }
callbacks["window.open"](waiting)
placed(waiting, 7, 480, 680)

local already_open = window(40, title)
local manually_moved = window(41, title)
manually_moved.floating = true
existing = { already_open, manually_moved, window(42, "Bitwarden — Mozilla Firefox") }
callbacks["config.reloaded"]()
placed(already_open, 10, 480, 680)
callbacks["window.title"](manually_moved)
assert(#dispatched == 12, "reload changed an existing floating window")

callbacks["window.destroy"](login)
callbacks["window.open"](login)
placed(login, 13, 480, 680)
for i, monitor in ipairs({
  { width = 1000, height = 1200, scale = 2, transform = 0 },
  { width = 1200, height = 1000, scale = 2, transform = 1 },
}) do
  local scaled = window(50 + i, title)
  scaled.monitor = monitor
  local first = #dispatched + 1
  callbacks["window.open"](scaled)
  placed(scaled, first, 460, 528)
end
print("PASS: late Bitwarden titles target only the extension; placement is bounded and preserves manual changes")
