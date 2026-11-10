require("lua.overview").register()

local exec_once = {
  "hypr-tray-applets",
  "orgm-hyprland-session",
  "hyprpolkitagent",
  -- The default browser restores its previous session.
  "sh -c 'if command -v orgm-browser >/dev/null 2>&1; then exec orgm-browser; else exec firefox; fi'",
  "sh -lc 'mkdir -p \"${XDG_STATE_HOME:-$HOME/.local/state}/hypr-battery-alerts\"; hypr-battery-alerts daemon >>\"${XDG_STATE_HOME:-$HOME/.local/state}/hypr-battery-alerts/helper.log\" 2>&1'",
}

hl.on("hyprland.start", function()
  for _, cmd in ipairs(exec_once) do
    hl.exec_cmd(cmd)
  end
end)
