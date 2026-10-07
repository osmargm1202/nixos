local name = "orgm-ryoku.shortcuts"
local config = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
if not package.loaded[name] then
  package.loaded[name] = assert(loadfile(config .. "/orgm-ryoku/shortcuts.lua"))()
end
package.loaded[name].install()

-- Native scrolling column presets: one third, one half and the whole viewport.
-- Keep the user's selected layout and default width under Hub ownership.
hl.config({ scrolling = {
  explicit_column_widths = "0.333, 0.5, 1.0",
  -- A lone column must also honor the selected width instead of forcing 100%.
  fullscreen_on_one_column = false,
} })

-- Personal placement rules belong to this user and this desktop profile.
assert(loadfile(config .. "/orgm-ryoku/window-rules.lua"))().setup()

-- Kitty owns the background alpha. Avoid multiplying it again by the desktop
-- inactive opacity, including the personal AI and native SSH terminal classes.
hl.window_rule({
  name = "orgm-kitty-opacity",
  match = { class = "^(kitty|orgmai-(chat|config)|ryoport-ssh)$" },
  opacity = "1 override 1 override 1 override",
})

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
