local exec_once = {
  "hyprctl plugin load /etc/scrolloverview.so",
  "hyprctl plugin load /etc/hyprglass.so",
  "hyprctl reload",
  "hyprctl plugin load /etc/HyprWindowShade.so",
  -- Import the graphical session before starting StatusNotifier clients.
  "hypr-tray-applets",
  -- Apply the visual profile before consumers start, then reassert persisted
  -- game-mode wallpaper visibility so an active game session stays hidden.
  "hypr-session-refresh",
  "hyprpolkitagent",
  "kdeconnect-indicator",
  -- Firefox's declarative startup policy restores the previous session.
  "firefox",
  -- Keep chat and games ready without opening either client window.
  "hypr-start-discord",
  "sh -lc 'command -v steam >/dev/null 2>&1 && exec steam -silent || true'",
  "systemctl --user --quiet start sunshine.service || true",
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
