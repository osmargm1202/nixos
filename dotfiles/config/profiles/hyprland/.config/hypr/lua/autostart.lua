require("lua.overview").register()

local exec_once = {
  "hypr-tray-applets",
  "orgm-hyprland-session",
  "hyprpolkitagent",
  -- Firefox's declarative startup policy restores the previous session.
  "firefox",
  "sh -lc 'mkdir -p \"${XDG_STATE_HOME:-$HOME/.local/state}/hypr-battery-alerts\"; hypr-battery-alerts daemon >>\"${XDG_STATE_HOME:-$HOME/.local/state}/hypr-battery-alerts/helper.log\" 2>&1'",
}

hl.on("hyprland.start", function()
  for _, cmd in ipairs(exec_once) do
    hl.exec_cmd(cmd)
  end
end)
