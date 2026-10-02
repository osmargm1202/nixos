local name = "orgm-ryoku.shortcuts"
local config = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
if not package.loaded[name] then
  package.loaded[name] = assert(loadfile(config .. "/orgm-ryoku/shortcuts.lua"))()
end
package.loaded[name].install()

-- Only personal application startup; Ryoku owns shell, portals, idle, lock,
-- notifications, wallpapers, lighting and monitor detection.
hl.on("hyprland.start", function()
  for _, command in ipairs({
    "tailscale systray --theme light", "nextcloud --background",
    "syncthingtray --single-instance --wait", "kdeconnect-indicator", "firefox",
    "sh -lc 'command -v discord >/dev/null 2>&1 && exec discord --start-minimized || true'",
    "sh -lc 'command -v steam >/dev/null 2>&1 && exec steam -silent || true'",
    "systemctl --user --quiet start sunshine.service || true",
  }) do hl.exec_cmd(command) end
end)
