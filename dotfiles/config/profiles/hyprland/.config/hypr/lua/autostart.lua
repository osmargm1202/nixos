local exec_once = {
  "hyprctl plugin load /etc/scrolloverview.so",
  -- Import the graphical session before starting StatusNotifier clients.
  "hypr-tray-applets",
  -- Keep the lightweight Waybar process and its helper modules alive.
  "sh -lc 'hypr-display-targets ensure || true; exec waybar-watch \"$HOME/.config/waybar-hypr\"'",
  -- Restore the selected static wallpaper without a persistent selector daemon.
  "hypr-wallpaper restore",
  "hyprpolkitagent",
  "kdeconnect-indicator",
  "sh -lc 'exec \"$HOME/.local/bin/hypr-nwg-dock\"'",
  -- Lock and suspend on the established idle schedule.
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
