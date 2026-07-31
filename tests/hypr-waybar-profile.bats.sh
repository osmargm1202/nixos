#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

attr='.#nixosConfigurations.lenovo-hyprland.config.home-manager.users.osmarg.home.file'
paths=(
  '.config/waybar-hypr'
  '.config/nwg-dock-hyprland'
  '.local/bin/waybar-date-es'
  '.local/bin/waybar-day-month-es'
  '.local/bin/waybar-time-ampm'
  '.local/bin/waybar-watch'
  '.local/bin/hypr-reload-after-switch'
  '.local/bin/hypr-nwg-dock'
  '.local/bin/hypr-nwg-dock-reload'
)

for path in "${paths[@]}"; do
  [[ -e "dotfiles/config/profiles/hyprland/$path" ]]
  nix eval --raw "$attr.\"$path\".source" >/dev/null
done

config='dotfiles/config/profiles/hyprland/.config/waybar-hypr/config'
jq -e '
  length == 1
  and .[0]["modules-left"] == [
    "custom/menu", "custom/ws_1", "custom/ws_2", "custom/ws_3",
    "custom/ws_4", "custom/ws_5", "custom/ws_6", "custom/ws_7",
    "custom/ws_8", "custom/ws_9", "custom/ws_10", "custom/ws_special",
    "backlight", "battery", "pulseaudio", "pulseaudio#microphone",
    "idle_inhibitor", "custom/kbd_layout", "custom/wallpaper",
    "custom/keybindings_help"
  ]
  and .[0]["modules-center"] == ["custom/day_month", "custom/time", "custom/date"]
  and .[0]["modules-right"] == ["hyprland/window", "mpris", "custom/power", "tray"]
  and .[0]["custom/power"]["on-click"] == "hypr-power-menu"
' "$config" >/dev/null
printf '%s\n' 'hypr-waybar-profile: ok'
