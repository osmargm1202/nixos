-- Desktop icons via xfdesktop. Runs as its own layer-shell namespace
-- ("desktop") so it can be excluded from blur/anim without touching
-- the panel, which lives under the "gtk-layer-shell" namespace.
local exec_once = {
  "xfdesktop --disable-wm-check",
  "xfce4-panel",
}

hl.on("hyprland.start", function()
  for _, cmd in ipairs(exec_once) do
    hl.exec_cmd(cmd)
  end
end)

hl.layer_rule({
  match = { namespace = "desktop" },
  blur = false,
  order = 1,
  no_anim = true,
})

hl.layer_rule({
  match = { namespace = "gtk-layer-shell" },
  blur = true,
  ignore_alpha = 0.1,
})
