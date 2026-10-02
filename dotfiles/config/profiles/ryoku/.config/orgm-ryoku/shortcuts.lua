-- Preserve Osmarg's current bindings, adapting desktop actions to Ryoku.
local M = { personal = {}, relocated = {}, reserved = {}, used = {} }
local real = hl
-- XKB gives these spelling pairs the same keysym. Compare the physical
-- binding too, so Next cannot bypass a personal Page_Down reservation.
local aliases = {
  PRIOR = "PAGE_UP", NEXT = "PAGE_DOWN", QUOTELEFT = "GRAVE",
  KP_PRIOR = "KP_PAGE_UP", KP_NEXT = "KP_PAGE_DOWN",
}

function M.normalize(chord)
  local modifiers, key = {}, nil
  for token in chord:gmatch("[^+]+") do
    token = token:match("^%s*(.-)%s*$"):upper()
    if token == "SUPER" or token == "CTRL" or token == "ALT" or token == "SHIFT" then
      modifiers[token] = true
    else
      key = aliases[token] or token
    end
  end
  local parts = {}
  for _, modifier in ipairs({ "SUPER", "CTRL", "ALT", "SHIFT" }) do
    if modifiers[modifier] then parts[#parts + 1] = modifier end
  end
  parts[#parts + 1] = key or ""
  return table.concat(parts, " + ")
end

local globals = {
  ["hypr-app-launcher"] = "ryoku:launcher",
  ["hypr-main-menu"] = "ryoku:quicksettings",
  ["hypr-power-menu"] = "ryoku:quicksettings",
  ["hypr-rofi-clipboard"] = "ryoku:clipboard",
}
local commands = {
  ["hypr-keybindings-help"] = "orgm-ryoku-shortcuts",
  ["hypr-wallpaper random-menu"] = "ryogami wallpaper ui",
  ["hypr-lock"] = "ryoku-shell lock",
  ["hypr-shader-menu"] = "ryoku-shell hub open",
  ["volume-osd up"] = "ryoku-volume up",
  ["volume-osd down"] = "ryoku-volume down",
  ["volume-osd mute"] = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle",
  ["mic-volume-osd up"] = "wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 5%+",
  ["mic-volume-osd down"] = "wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 5%-",
  ["mic-volume-osd mute"] = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle",
  ["brightness-osd up"] = "ryoku-cmd-brightness +5",
  ["brightness-osd down"] = "ryoku-cmd-brightness -5",
}
local proxy = setmetatable({
  bind = function(chord, action, options)
    local normalized = M.normalize(chord)
    assert(not M.reserved[normalized], "duplicate Osmarg shortcut: " .. chord)
    M.reserved[normalized] = true
    M.personal[#M.personal + 1] = { chord, action, options }
  end,
  dsp = setmetatable({
    exec_cmd = function(command)
      if globals[command] then return real.dsp.global(globals[command]) end
      return real.dsp.exec_cmd(commands[command] or command)
    end,
  }, { __index = real.dsp }),
  -- The personal Alt+Tab handler retains its key and uses Ryoku's overview.
  plugin = { scrolloverview = {
    overview = function() real.dispatch(real.dsp.global("ryoku:overview")) end,
  } },
}, { __index = real })

local config = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
local env = setmetatable({ hl = proxy }, { __index = _G })
local personal = assert(loadfile(config .. "/orgm-ryoku/osmarg-keybindings.lua", "t", env))()
personal.setup({
  terminal = "kitty", fileManager = "ryoku-app files",
  app_launcher = "hypr-app-launcher", control_center = "hypr-main-menu",
  lock = "hypr-lock", power_menu = "hypr-power-menu",
  piPrompt = "hypr-pi-prompt --launcher rofi",
})

-- All four modifiers form a namespace absent from both pinned configurations.
-- Retain free Ryoku chords; relocate only collisions, including GUI rebinds.
function M.rebind(original, requested)
  local normalized = M.normalize(requested)
  if not M.reserved[normalized] and not M.used[normalized] then
    M.used[normalized] = true
    return requested
  end
  local key = requested:match("([^+]+)$"):match("^%s*(.-)%s*$")
  local candidate = "SUPER + CTRL + ALT + SHIFT + " .. key
  local index = 0
  while M.reserved[M.normalize(candidate)] or M.used[M.normalize(candidate)] do
    index = index + 1
    assert(index <= 35, "Ryoku shortcut namespace exhausted")
    candidate = "SUPER + CTRL + ALT + SHIFT + F" .. index
  end
  M.used[M.normalize(candidate)] = true
  M.relocated[#M.relocated + 1] = { original, candidate }
  return candidate
end

function M.install()
  for _, binding in ipairs(M.personal) do
    real.bind(binding[1], binding[2], binding[3])
  end
  local state = os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")
  local report = io.open(state .. "/orgm-ryoku/shortcuts.tsv", "w")
  if report then
    for _, binding in ipairs(M.personal) do report:write("Osmarg\t", binding[1], "\n") end
    for _, binding in ipairs(M.relocated) do
      report:write("Ryoku\t", binding[1], " → ", binding[2], "\n")
    end
    report:close()
  end
end

return M
