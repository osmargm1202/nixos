hl.config({
  input = {
    kb_layout = "us,latam",
    kb_variant = "altgr-intl,",
    kb_model = "",
    kb_options = "grp:ctrl_space_toggle",
    kb_rules = "",
    numlock_by_default = true,
    follow_mouse = 1,
    sensitivity = 0,
    touchpad = {
      natural_scroll = true,
      tap_to_click = true,
      drag_lock = true,
    },
  },
  gestures = {
    workspace_swipe_distance = 300,
    workspace_swipe_invert = true,
    workspace_swipe_cancel_ratio = 0.5,
    workspace_swipe_min_speed_to_force = 30,
    workspace_swipe_create_new = false,
    workspace_swipe_direction_lock = true,
  },
})

hl.gesture({
  fingers = 3,
  direction = "horizontal",
  action = "workspace",
})
