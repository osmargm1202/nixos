local hyprdeck = require("lua.hyprdeck")

local misc = {
  force_default_wallpaper = 0,
  disable_hyprland_logo = true,
}

local group = nil

if hyprdeck.enabled then
  -- Avoids a flicker where hyprdeck merges every new window into its
  -- workspace group a frame after it opens instead of already grouped.
  misc.exit_window_retains_fullscreen = false

  group = {
    auto_group = true,
    focus_removed_window = false,
    insert_after_current = true,
    group_on_movetoworkspace = true,

    groupbar = {
      enabled = true,
      render_titles = true,
      scrolling = true,
      middle_click_close = true,

      height = 22,
      font_size = 12,
      font_family = "Sans",
      text_padding = 0,

      gradients = true,
      indicator_height = 0,

      col = {
        active = "rgba(33ccff30)",
        inactive = "rgba(2a2a2a55)",
      },

      text_color = "rgba(ffffffdd)",
      text_color_inactive = "rgba(b0b0b0ff)",

      gradient_rounding = 8,
      gradient_round_only_edges = false,

      gaps_in = 8,
      gaps_out = 5,
      keep_upper_gap = false,
    },
  }
end

hl.config({
  dwindle = {
    preserve_split = true,
  },
  master = {
    new_status = "master",
  },
  scrolling = {
    fullscreen_on_one_column = true,
    column_width = 0.5,
    focus_fit_method = 0,
    follow_focus = true,
    follow_min_visible = 0.4,
    explicit_column_widths = "0.333, 0.5, 0.667, 1.0",
    direction = "right",
  },
  group = group,
  misc = misc,
})
