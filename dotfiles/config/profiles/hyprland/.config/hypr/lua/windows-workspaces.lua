-- Hyprland 0.55 Lua window rules.

-- Force dark mode in Hyprland window opacity presets.
local light_mode = false
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

-- Browser web-notification popups (chromium, zen, brave-origin): keep them
-- floating at their own popup size, pinned top-right, instead of tiling.
local browser_notification_classes = {
  "^(chromium|Chromium)$",
  "^(brave-browser|Brave-browser|brave-origin)$",
  "^(app.zen_browser.zen|zen-browser|zen(-beta)?)$",
  "^(chrome-.*)$", -- PWAs (WhatsApp, etc.) spawn popups under their own class
}

for _, cls in ipairs(browser_notification_classes) do
  hl.window_rule({
    match = { class = cls, title = "^(.*[Nn]otificaci[oó]n.*|.*[Nn]otification.*)$" },
    float = true,
    pin = true,
    no_initial_focus = true,
    move = "100%-w-20 60",
  })
end

hl.window_rule({ match = { title = "^hardware-fastfetch$" }, maximize = true })

hl.window_rule({ match = { modal = true }, float = true })

-- Discord starts normally; no forced scratchpad.

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
