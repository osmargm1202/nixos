hl.config({
  general = {
    gaps_in = 12,
    gaps_out = 12,
    border_size = 3,
    col = {
      active_border = { colors = { "rgba(8aadf4ee)", "rgba(f5a97fee)" }, angle = 45 },
      inactive_border = "rgba(363a4faa)",
    },
    resize_on_border = false,
    allow_tearing = false,
    layout = "dwindle",
  },

  group = {
    col = {
      border_active = { colors = { "rgba(ff3355ee)", "rgba(b455ffee)" }, angle = 45 },
      border_inactive = { colors = { "rgba(80305099)", "rgba(5a3d8a99)" }, angle = 45 },
      border_locked_active = { colors = { "rgba(ff6b35ee)", "rgba(b455ffee)" }, angle = 45 },
      border_locked_inactive = { colors = { "rgba(5a223899)", "rgba(3f2a6099)" }, angle = 45 },
    },
    groupbar = {
      font_size = 24,
      height = 42,
      gradients = true,
      col = {
        active = "rgba(8aadf4ee)",
        inactive = "rgba(00161acc)",
        locked_active = "rgba(f5a97fee)",
        locked_inactive = "rgba(00161acc)",
      },
    },
  },

  decoration = {
    rounding = 12,
    rounding_power = 2,
    active_opacity = 0.96,
    inactive_opacity = 0.96,
    fullscreen_opacity = 1.0,
    shadow = {
      enabled = true,
      range = 18,
      render_power = 3,
      color = "rgba(00000070)",
    },
    blur = {
      enabled = true,
      size = 6,
      passes = 3,
      vibrancy = 0.2,
      new_optimizations = true,
    },
  },

  animations = {
    enabled = true,
  },
})

hl.layer_rule({
  name = "blur-top-bar",
  match = { namespace = "top_bar" },
  blur = true,
  ignore_alpha = 0.1,
})

hl.layer_rule({
  name = "blur-bottom-bar",
  match = { namespace = "bottom_bar" },
  blur = true,
  ignore_alpha = 0.1,
})

hl.layer_rule({
  name = "blur-nwg-dock",
  match = { namespace = "nwg-dock" },
  blur = true,
  ignore_alpha = 0.10,
})

hl.layer_rule({
  name = "blur-swaync",
  match = { namespace = "swaync" },
  blur = true,
  ignore_alpha = 0.10,
})

hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })
hl.curve("wind", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })
hl.curve("overshot", { type = "bezier", points = { { 0.18, 0.95 }, { 0.22, 1.03 } } })

local function hypr_menu_env_path()
  local config_home = os.getenv("XDG_CONFIG_HOME")
  if config_home == nil or config_home == "" then
    local home = os.getenv("HOME")
    if home == nil or home == "" then
      return nil
    end
    config_home = home .. "/.config"
  end
  return config_home .. "/rofi/hypr-menu.env"
end

local function read_workspace_animation_env_file()
  local path = hypr_menu_env_path()
  if path == nil then
    return nil
  end

  local file = io.open(path, "r")
  if file == nil then
    return nil
  end

  for line in file:lines() do
    local value = line:match("^%s*HYPR_WORKSPACE_ANIMATION%s*=%s*(.-)%s*$")
    if value ~= nil and value ~= "" then
      file:close()
      return value
    end
  end

  file:close()
  return nil
end

local function workspace_animation_preset()
  local value = os.getenv("HYPR_WORKSPACE_ANIMATION")
  if value == nil or value == "" then
    value = read_workspace_animation_env_file()
  end
  if value == nil or value == "" then
    value = "fade"
  end

  local presets = {
    fade = { enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" },
    slide = { enabled = true, speed = 5, bezier = "wind", style = "slide" },
    slidevert = { enabled = true, speed = 5, bezier = "wind", style = "slidevert" },
    slidefade = { enabled = true, speed = 5, bezier = "wind", style = "slidefade 20%" },
    slidefadevert = { enabled = true, speed = 5, bezier = "wind", style = "slidefadevert 20%" },
    hyde = { enabled = true, speed = 5, bezier = "wind" },
    limefrenzy = { enabled = true, speed = 5, bezier = "overshot", style = "slidevert" },
    off = { enabled = false, speed = 1, bezier = "default" },
  }
  return presets[value] or presets.fade
end

local workspace_animation = workspace_animation_preset()

hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows", enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1, bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49, bezier = "almostLinear", style = "popin 87%" })
hl.animation({ leaf = "fade", enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers", enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({
  leaf = "workspaces",
  enabled = workspace_animation.enabled,
  speed = workspace_animation.speed,
  bezier = workspace_animation.bezier,
  style = workspace_animation.style,
})
