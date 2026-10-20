hl.config({
  dwindle = {
    preserve_split = true,
  },
  master = {
    new_status = "master",
  },
  scrolling = {
    -- Respect manual width cycling even when the workspace has only one column.
    fullscreen_on_one_column = false,
    column_width = 0.5,
    focus_fit_method = 1,
    follow_focus = true,
    follow_min_visible = 0.4,
    explicit_column_widths = "0.333, 0.5, 0.667, 1.0",
    direction = "right",
  },
  misc = {
    force_default_wallpaper = 0,
    disable_hyprland_logo = true,
    enable_anr_dialog = false,
  },
})
