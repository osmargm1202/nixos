local exec_once = {
  "hypr-session-import-env",
  "systemctl --user start sunshine.service",
  "sh -lc '$HOME/.local/bin/hypr-display-targets ensure && $HOME/.local/bin/waybar-watch ~/.config/waybar-hypr'",
  "sh -lc 'orgm-wallpaper restore >>/tmp/orgm-wallpaper.log 2>&1'",
  "sh -lc 'orgm-wallpaper daemon >>/tmp/orgm-wallpaper.log 2>&1'",
  "swaync",
  "nm-applet --indicator",
  "blueman-applet",
  "gnome-keyring-daemon --start --components=secrets,pkcs11,ssh",
  "hyprpolkitagent",
  "sh -lc 'mkdir -p ${XDG_STATE_HOME:-$HOME/.local/state}/hypr-battery-alerts && hypr-battery-alerts daemon >>${XDG_STATE_HOME:-$HOME/.local/state}/hypr-battery-alerts/helper.log 2>&1'",
  "nextcloud --background",
  "hypr-start-containers arch windows",
  "hypr-start-discord",
  "wl-paste --type text --watch cliphist store",
  "wl-paste --type image --watch cliphist store",
  "hypridle",
  "sh -lc '$HOME/.local/bin/hypr-nwg-dock 2>/tmp/hypr-nwg-dock.log'",
  "sh -lc 'sleep 2 && conky -c ~/.config/conky/conky.conf -d && conky -c ~/.config/conky/conky-clock.conf -d && conky -c ~/.config/conky/conky-apps.conf -d'",
}

hl.on("hyprland.start", function()
  for _, cmd in ipairs(exec_once) do
    hl.exec_cmd(cmd)
  end
end)
