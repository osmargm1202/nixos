-- Hyprland 0.55 Lua window rules.

local function current_theme_name()
  local state_home = os.getenv("XDG_STATE_HOME") or ((os.getenv("HOME") or "") .. "/.local/state")
  local file = io.open(state_home .. "/orgm-theme/current", "r")
  if not file then
    return "orgm-dark"
  end
  local theme = file:read("*l") or "orgm-dark"
  file:close()
  return theme
end

local light_mode = current_theme_name() == "orgm-light"
local opaque = "1.0 override 1.0 override 1.0 override"
local base_opacity = light_mode and opaque or "0.96 override 0.96 override 1.0 override"
local file_opacity = light_mode and opaque or "0.88 override 0.88 override 1.0 override"
local terminal_opacity = light_mode and opaque or "0.85 override 0.85 override 1.0 override"
local browser_opacity = light_mode and opaque or "0.90 override 0.90 override 1.0 override"

local opacity_rules = {
  { class = ".*", opacity = base_opacity },
  -- Dark mode uses translucent windows so Hyprland blur is noticeable behind them.
  -- Light mode is fully opaque to preserve contrast and avoid washed-out terminals.
  { class = "^(org.gnome.Nautilus)$", opacity = file_opacity },
  { class = "^(kitty)$", opacity = terminal_opacity },
  { class = "^(dev.warp.Warp)$", opacity = terminal_opacity },
  { class = "^(vesktop)$", opacity = browser_opacity },
  { class = "^(discord)$", opacity = browser_opacity },
  { class = "^(com.discordapp.Discord)$", opacity = browser_opacity },
  { class = "^(spotify)$", opacity = browser_opacity },
  { class = "^(obsidian)$", opacity = browser_opacity },
  { class = "^(app.zen_browser.zen)$", opacity = browser_opacity },
  { class = "^(zen-browser)$", opacity = browser_opacity },
  { class = "^(chromium)$", opacity = browser_opacity },
  { class = "^(Chromium)$", opacity = browser_opacity },
}

for _, rule in ipairs(opacity_rules) do
  hl.window_rule({
    match = { class = rule.class },
    opacity = rule.opacity,
  })
end

local utilities = {
  { class = "^(org.gnome.Calculator)$", size = "420 520" },
  { class = "^(pavucontrol)$", size = "760 520" },
  { class = "^(blueman-manager)$", size = "760 520" },
  { class = "^(nm-connection-editor)$", size = "820 560" },
  { class = "^(nwg-displays)$", size = "980 640" },
  { class = "^(org.gnome.FileRoller)$", size = "820 560" },
}

for _, rule in ipairs(utilities) do
  hl.window_rule({ match = { class = rule.class }, float = true })
  hl.window_rule({ match = { class = rule.class }, size = rule.size })
  hl.window_rule({ match = { class = rule.class }, center = true })
end

hl.window_rule({ match = { title = "^hardware-fastfetch$" }, maximize = true })

hl.window_rule({ match = { modal = true }, float = true })

-- Discord starts normally; no forced scratchpad.

-- Conky background widgets: wlr-layer-shell bottom, transparent via own_window_transparent=true
hl.layer_rule({ match = { namespace = "conky_namespace" }, blur = true })

-- Conky overlay: XWayland stats shown above windows for 4s via toggle button
hl.window_rule({ match = { class = "^conky-overlay$" }, float = true })
hl.window_rule({ match = { class = "^conky-overlay$" }, pin = true })
hl.window_rule({ match = { class = "^conky-overlay$" }, no_initial_focus = true })
hl.window_rule({ match = { class = "^conky-overlay$" }, border_size = 0 })
hl.window_rule({ match = { class = "^conky-overlay$" }, rounding = 0 })
hl.window_rule({ match = { class = "^conky-overlay$" }, no_shadow = true })

hl.window_rule({
  name = "fix-xwayland-empty-class-drags",
  match = {
    class = "^$",
    title = "^$",
    xwayland = true,
    float = true,
    fullscreen = false,
    pin = false,
  },
  no_focus = true,
})
