local config = assert(os.getenv("XDG_CONFIG_HOME"))
local callbacks, dispatched, existing, rules = {}, {}, {}, {}
local focused, cursor
hl = {
  window_rule = function(rule) rules[#rules + 1] = rule end,
  on = function(event, callback) callbacks[event] = callback end,
  get_windows = function() return existing end,
  dispatch = function(action)
    dispatched[#dispatched + 1] = action
    local target = action.options.window
    if action.name == "resize" then
      target.size = { x = action.options.x, y = action.options.y }
    elseif action.name == "center" then
      target.at = { x = 100, y = 200 }
    elseif action.name == "focus" then
      focused = target
    elseif action.name == "cursor" then
      cursor = { x = action.options.x, y = action.options.y }
    end
  end,
  dsp = { window = {}, cursor = {} },
}
for _, name in ipairs({ "float", "resize", "center" }) do
  hl.dsp.window[name] = function(options) return { name = name, options = options } end
end
hl.dsp.focus = function(options) return { name = "focus", options = options } end
hl.dsp.cursor.move = function(options) return { name = "cursor", options = options } end
assert(loadfile(config .. "/orgm-ryoku/window-rules.lua"))().setup()
assert(#rules == 5)
for _, rule in ipairs(rules) do
  assert(rule.float and rule.center and rule.focus_on_activate)
  assert(rule.no_initial_focus == false and rule.no_follow_mouse == false)
end
local title = "Extension: (Bitwarden Password Manager) - Bitwarden — Mozilla Firefox"
local function window(id, window_title, class)
  return {
    stable_id = id, class = class or "firefox", title = window_title, mapped = true,
    floating = false, monitor = { width = 1920, height = 1080, scale = 1, transform = 0 },
    at = { x = 20, y = 30 }, size = { x = 640, y = 480 },
  }
end
local function check_focus(target, first)
  assert(dispatched[first].name == "focus" and dispatched[first].options.window == target)
  local move = dispatched[first + 1]
  assert(move.name == "cursor")
  assert(move.options.x == math.floor(target.at.x + target.size.x / 2))
  assert(move.options.y == math.floor(target.at.y + target.size.y / 2))
  assert(focused == target, "focused a different window")
end
local function placed(target, first, width, height, takes_focus)
  assert(dispatched[first].name == "float" and dispatched[first].options.action == "set")
  local resize = dispatched[first + 1]
  assert(resize.name == "resize" and resize.options.relative == false)
  assert(resize.options.x == width and resize.options.y == height)
  assert(dispatched[first + 2].name == "center")
  for i = first, first + 2 do
    assert(dispatched[i].options.window == target, "acted on focused window instead of extension")
  end
  if takes_focus ~= false then check_focus(target, first + 3) end
end
local function expect_placement(target, width, height)
  local first = #dispatched + 1
  callbacks["window.open"](target)
  placed(target, first, width or 480, height or 680)
end
local function no_repeat(target)
  local count = #dispatched
  callbacks["window.title"](target)
  callbacks["window.open"](target)
  assert(#dispatched == count, "repeated events must not change geometry or steal focus")
end

local login = window(1, "Mozilla Firefox")
callbacks["window.open"](login)
assert(#dispatched == 0)
login.title = title
callbacks["window.title"](login)
placed(login, 1, 480, 680)
no_repeat(login)

local count = #dispatched
for i, other_title in ipairs({ "Bitwarden", "Bitwarden — Mozilla Firefox", "Bitwarden documentation — Mozilla Firefox" }) do
  callbacks["window.title"](window(10 + i, other_title))
end
for i, class in ipairs({ "kitty", "chromium-browser", "chrome-www.bitwarden.com-Default", "chrome-other-extension-Default" }) do
  callbacks["window.title"](window(20 + i, "Bitwarden", class))
end
callbacks["window.title"](window(29, "Syncthing Tray", "firefox"))
callbacks["window.title"](nil)
local unmapped = window(25, title)
unmapped.mapped = false
callbacks["window.title"](unmapped)
assert(#dispatched == count, "matched a browser tab or an unrelated/unmapped client")

-- The real Chromium extension app_id works before its Bitwarden title arrives.
local chromium = window(26, "_crx_nngceckbapebfimnlniiiahkandclblb", "chrome-nngceckbapebfimnlniiiahkandclblb-Default")
expect_placement(chromium)
chromium.title = "Bitwarden"
no_repeat(chromium)
expect_placement(window(27, "Bitwarden", "chrome-nngceckbapebfimnlniiiahkandclblb-Profile_1"))
expect_placement(window(28, "Extensión: (Bitwarden Password Manager) - Bitwarden", "org.mozilla.firefox"))

local small = window(30, title)
small.monitor = { width = 500, height = 600, scale = 1, transform = 0 }
expect_placement(small, 460, 528)
local waiting = window(31, title)
waiting.monitor = nil
count = #dispatched
callbacks["window.title"](waiting)
assert(#dispatched == count)
waiting.monitor = { width = 1920, height = 1080, scale = 1, transform = 0 }
expect_placement(waiting)
for i, monitor in ipairs({
  { width = 1000, height = 1200, scale = 2, transform = 0 },
  { width = 1200, height = 1000, scale = 2, transform = 1 },
}) do
  local scaled = window(50 + i, title)
  scaled.monitor = monitor
  expect_placement(scaled, 460, 528)
end

-- Calculator and all existing utility/tray windows get initial focus and the
-- pointer, without repeating it when their titles change or they lose focus.
for i, fixture in ipairs({
  { "org.gnome.Calculator", "Calculator" }, { "qalculate-gtk", "Qalculate!" },
  { "Qalculate-qt", "Qalculate!" }, { "orgmai-chat", "Chat" },
  { "orgmai-config", "Settings" },
  { "com.nextcloud.desktopclient.nextcloud", "Nextcloud" }, { "", "Syncthing Tray" },
}) do
  local target = window(60 + i, fixture[2], fixture[1])
  local first = #dispatched + 1
  callbacks["window.open"](target)
  check_focus(target, first)
  no_repeat(target)
  callbacks["window.close"](target)
  first = #dispatched + 1
  callbacks["window.open"](target)
  check_focus(target, first)
end
count = #dispatched
callbacks["window.title"](window(80, "Nextcloud settings", "com.nextcloud.desktopclient.nextcloud"))
assert(#dispatched == count, "focused a non-tray Nextcloud window")

local already_open = window(40, title)
local manually_moved = window(41, title)
manually_moved.floating = true
local existing_calculator = window(42, "Calculator", "org.gnome.Calculator")
existing = { already_open, manually_moved, existing_calculator, window(43, "Bitwarden — Mozilla Firefox") }
local first = #dispatched + 1
local before_focus, before_cursor = focused, cursor
callbacks["config.reloaded"]()
placed(already_open, first, 480, 680, false)
assert(focused == before_focus and cursor == before_cursor, "reload stole focus or moved the pointer")
count = #dispatched
callbacks["window.title"](manually_moved)
callbacks["window.title"](already_open)
callbacks["window.title"](existing_calculator)
assert(#dispatched == count, "reload changed existing placement or allowed stale title events to steal focus")

callbacks["window.destroy"](login)
expect_placement(login)
callbacks["window.close"](chromium)
expect_placement(chromium)
print("PASS: Firefox/Chromium Bitwarden and utility windows get one initial focus and cursor warp; reload preserves manual placement and focus")
