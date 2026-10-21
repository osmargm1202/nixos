require("lua.overview").register()

local exec_once = {
  -- Import the graphical session before starting StatusNotifier clients.
  "hypr-tray-applets",
  -- Apply the visual profile before consumers start, then reassert persisted
  -- game-mode wallpaper visibility so an active game session stays hidden.
  "orgm-hyprland-session",
  "hyprpolkitagent",
  "kdeconnect-indicator",
  -- Firefox's declarative startup policy restores the previous session.
  "firefox",
  -- Keep chat and games ready without opening either client window.
  "hypr-start-discord",
  "sh -lc 'command -v steam >/dev/null 2>&1 && exec steam -silent || true'",
  "systemctl --user --quiet start sunshine.service || true",
  -- Lock and suspend on the established idle schedule.
  "sh -lc 'mkdir -p \"${XDG_STATE_HOME:-$HOME/.local/state}/hypr-battery-alerts\"; hypr-battery-alerts daemon >>\"${XDG_STATE_HOME:-$HOME/.local/state}/hypr-battery-alerts/helper.log\" 2>&1'",
}

hl.on("hyprland.start", function()
  for _, cmd in ipairs(exec_once) do
    hl.exec_cmd(cmd)
  end
end)
