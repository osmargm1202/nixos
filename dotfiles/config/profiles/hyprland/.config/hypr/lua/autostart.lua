local exec_once = {
  "hyprctl plugin load /etc/scrolloverview.so",
  "sh -lc 'hypr-session-import-env && systemctl --user start nixos-fake-graphical-session.target'",
  "sh -lc 'mkdir -p ${XDG_STATE_HOME:-$HOME/.local/state}/orgm-theme && printf \'orgm-dark\\n\' >\"${XDG_STATE_HOME:-$HOME/.local/state}/orgm-theme/current\"'",
  "systemctl --user start sunshine.service",
  "sh -lc '$HOME/.local/bin/hypr-display-targets ensure && $HOME/.local/bin/waybar-watch ~/.config/waybar-hypr'",
  "swaync",
  "nm-applet --indicator",
  "blueman-applet",
  "gnome-keyring-daemon --start --components=secrets,pkcs11,ssh",
  "hyprpolkitagent",
  "sh -lc 'mkdir -p ${XDG_STATE_HOME:-$HOME/.local/state}/hypr-battery-alerts && hypr-battery-alerts daemon >>${XDG_STATE_HOME:-$HOME/.local/state}/hypr-battery-alerts/helper.log 2>&1'",
  "nextcloud --background",
  "hypr-start-discord",
  "wl-paste --type text --watch cliphist store",
  "wl-paste --type image --watch cliphist store",
  -- Loads saved RGB profile if one exists; no-op otherwise (keeps current config)
  "openrgb-autostart",
  "hypridle",
  "sh -lc '$HOME/.local/bin/hypr-nwg-dock 2>/tmp/hypr-nwg-dock.log'",

}

hl.on("hyprland.start", function()
  for _, cmd in ipairs(exec_once) do
    hl.exec_cmd(cmd)
  end
end)
