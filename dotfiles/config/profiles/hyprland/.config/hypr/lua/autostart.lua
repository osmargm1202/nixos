local exec_once = {
  "hyprctl plugin load /etc/scrolloverview.so",
  "hyprctl plugin load /etc/hyprglass.so",
  "hyprctl reload",
  "hyprctl plugin load /etc/HyprWindowShade.so",
  "hypr-tray-applets",
  "hypr-session-refresh",
  "hyprpolkitagent",
  -- Firefox's declarative startup policy restores the previous session.
  "firefox",
  "sh -lc 'exec \"$HOME/.local/bin/hypr-nwg-dock\"'",
  "hypridle",
  "sh -lc 'mkdir -p \"${XDG_STATE_HOME:-$HOME/.local/state}/hypr-battery-alerts\"; hypr-battery-alerts daemon >>\"${XDG_STATE_HOME:-$HOME/.local/state}/hypr-battery-alerts/helper.log\" 2>&1'",
  "wl-paste --type text --watch cliphist store",
  "wl-paste --type image --watch cliphist store",
}

hl.on("hyprland.start", function()
  for _, cmd in ipairs(exec_once) do
    hl.exec_cmd(cmd)
  end
end)
