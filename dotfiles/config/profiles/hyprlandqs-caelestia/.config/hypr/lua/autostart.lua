local exec_once = {
  "hyprctl plugin load /etc/scrolloverview.so",
  "hypr-session-import-env",
  "sh -lc 'sleep 0.5 && systemctl --user start nixos-fake-graphical-session.target'",
  "systemctl --user start sunshine.service",

  "nm-applet --indicator",
  "blueman-applet",
  "gnome-keyring-daemon --start --components=secrets,pkcs11,ssh",
  "hyprpolkitagent",
  "sh -lc 'mkdir -p ${XDG_STATE_HOME:-$HOME/.local/state}/hypr-battery-alerts && hypr-battery-alerts daemon >>${XDG_STATE_HOME:-$HOME/.local/state}/hypr-battery-alerts/helper.log 2>&1'",
  "nextcloud --background",
  "wl-paste --type text --watch cliphist store",
  "wl-paste --type image --watch cliphist store",
  -- hypridle is intentionally absent: caelestia manages idle/lock/dpms/sleep internally
  -- nwg-dock intentionally absent: caelestia has its own dock
  -- caelestia is started via systemd (programs.caelestia.systemd.enable = true in NixOS)
}

hl.on("hyprland.start", function()
  for _, cmd in ipairs(exec_once) do
    hl.exec_cmd(cmd)
  end
end)
