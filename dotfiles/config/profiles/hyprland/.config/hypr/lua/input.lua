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
      natural_scroll = false,
    },
  },
})

hl.gesture({
  fingers = 3,
  direction = "horizontal",
  action = "workspace",
})
