-- Hyprland 0.55 Lua window rules.

-- Force dark mode in Hyprland window opacity presets.
local game_mode = require("lua.game-mode").enabled()

local light_mode = false
local opaque = "1.0 override 1.0 override 1.0 override"
local base_opacity = game_mode and opaque or (light_mode and opaque or "0.96 override 0.96 override 1.0 override")
local file_opacity = game_mode and opaque or (light_mode and opaque or "0.88 override 0.88 override 1.0 override")
local terminal_opacity = game_mode and opaque or (light_mode and opaque or "0.85 override 0.85 override 1.0 override")
local browser_opacity = game_mode and opaque or (light_mode and opaque or "0.90 override 0.90 override 1.0 override")

local opacity_rules = {
  { class = ".*", opacity = base_opacity },
  -- Dark mode uses translucent windows so Hyprland blur is noticeable behind them.
  -- Light mode is fully opaque to preserve contrast and avoid washed-out terminals.
  { class = "^(org.gnome.Nautilus)$", opacity = file_opacity },
  { class = "^(hyprfm)$", opacity = file_opacity },
  { class = "^(kitty)$", opacity = terminal_opacity },
  { class = "^(dev.warp.Warp)$", opacity = terminal_opacity },
  { class = "^(vesktop)$", opacity = browser_opacity },
  { class = "^(firefox|Firefox)$", opacity = browser_opacity },
  { class = "^(discord)$", opacity = browser_opacity },
  { class = "^(com.discordapp.Discord)$", opacity = browser_opacity },
  { class = "^(spotify)$", opacity = browser_opacity },
  { class = "^(obsidian)$", opacity = browser_opacity },
}

for _, rule in ipairs(opacity_rules) do
  hl.window_rule({
    match = { class = rule.class },
    opacity = rule.opacity,
  })
end

-- Each daily-use app has an opening transition and is explicitly glassed.
-- HyprGlass replaces Hyprland's disabled decoration blur for these clients.
-- btop is a terminal app: its title rule overrides Kitty's transition.
local opening_transition_rules = {
  { match = { class = "^(kitty)$" }, shader = "fade", duration_ms = 200 },
  { match = { class = "^(chromium|Chromium)$" }, shader = "directional-wipe", duration_ms = 200 },
  { match = { class = "^(brave-browser|Brave-browser|brave-origin)$" }, shader = "crosswarp", duration_ms = 200 },
  { match = { class = "^(opera|Opera)$" }, shader = "flyeye", duration_ms = 200 },
  { match = { class = "^(obsidian)$" }, shader = "ink-splash", duration_ms = 200 },
  { match = { class = "^(com.obsproject.Studio|obs)$" }, shader = "plasma-flow", duration_ms = 200 },
  { match = { title = "^[Bb][Tt][Oo][Pp]$" }, shader = "static-fade", duration_ms = 200 },
  { match = { class = "^(vesktop)$" }, shader = "pixelate", duration_ms = 200 },
  { match = { class = "^(firefox|Firefox)$" }, shader = "pixelate", duration_ms = 200 },
  { match = { class = "^(discord|com.discordapp.Discord)$" }, shader = "pixelate", duration_ms = 200 },
  { match = { class = "^(libreoffice.*|LibreOffice.*)$" }, shader = "circle", duration_ms = 200 },
  { match = { class = "^(Code|code|code-oss|VSCodium)$" }, shader = "crosshatch", duration_ms = 200 },
  { match = { class = "^(Blender|blender)$" }, shader = "voronoi-shatter", duration_ms = 200 },
  { match = { class = "^(org.gnome.Nautilus)$" }, shader = "morph", duration_ms = 200 },
  { match = { class = "^(hyprfm)$" }, shader = "morph", duration_ms = 200 },
  { match = { class = "^(thunar|Thunar)$" }, shader = "ripple", duration_ms = 200 },
  { match = { class = "^(org.gnome.Calculator)$" }, shader = "snap", duration_ms = 200 },
  { match = { class = "^(pavucontrol)$" }, shader = "dissolve", duration_ms = 200 },
  { match = { class = "^(dev.warp.Warp)$" }, shader = "soft-warp-fade", duration_ms = 200 },
  { match = { class = "^(spotify)$" }, shader = "ripple", duration_ms = 200 },
}

if not game_mode then
  for _, rule in ipairs(opening_transition_rules) do
    hl.window_rule({ match = rule.match, tag = "+hyprglass_enabled" })
    hl.window_rule({ match = rule.match, tag = "+hyprglass_preset_glass" })
    hl.window_rule({
      match = rule.match,
      tag = "+shader_transition_open:/etc/hyprwindowshade-shaders/open/" .. rule.shader .. ".glsl",
    })
    hl.window_rule({
      match = rule.match,
      tag = "+shader_transition_duration_ms:" .. rule.duration_ms,
    })
  end

  local shader_preview_state = os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")
  local shader_override_file = io.open(shader_preview_state .. "/hypr/shader-overrides", "r")
  if shader_override_file then
    for line in shader_override_file:lines() do
      local class, shader = line:match("^([^\t]+)\t([%w%-]+)$")
      if class and shader then
        hl.window_rule({
          match = { class = class },
          tag = "+shader_transition_open:/etc/hyprwindowshade-shaders/open/" .. shader .. ".glsl",
        })
        hl.window_rule({
          match = { class = class },
          tag = "+shader_transition_duration_ms:200",
        })
      end
    end
    shader_override_file:close()
  end
  local shader_preview_file = io.open(shader_preview_state .. "/hypr/shader-preview", "r")
  if shader_preview_file then
    local shader_preview = shader_preview_file:read("*l")
    shader_preview_file:close()
    if shader_preview and shader_preview:match("^[%w%-]+$") then
      hl.window_rule({
        match = { class = "^(hypr-shader-preview)$" },
        tag = "+shader_transition_open:/etc/hyprwindowshade-shaders/open/" .. shader_preview .. ".glsl",
      })
      hl.window_rule({
        match = { class = "^(hypr-shader-preview)$" },
        tag = "+shader_transition_duration_ms:350",
      })
    end
  end
end


local utilities = {
  { class = "^(org.gnome.Calculator)$", size = "420 520" },
  { class = "^(pavucontrol)$", size = "760 520" },
  { class = "^(blueman-manager)$", size = "760 520" },
  { class = "^(nm-connection-editor)$", size = "820 560" },
  { class = "^(org.gnome.FileRoller)$", size = "820 560" },
}

for _, rule in ipairs(utilities) do
  hl.window_rule({ match = { class = rule.class }, float = true })
  hl.window_rule({ match = { class = rule.class }, size = rule.size })
  hl.window_rule({ match = { class = rule.class }, center = true })
end

-- Browser web-notification popups: keep them floating at their own popup
-- size, pinned top-right, instead of tiling.
local browser_notification_classes = {
  "^(firefox|Firefox)$",
  "^(brave-browser|Brave-browser|brave-origin)$",
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
