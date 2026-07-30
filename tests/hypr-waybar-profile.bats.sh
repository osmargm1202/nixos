#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

attr='.#nixosConfigurations.lenovo-i3.config.home-manager.users.osmarg.home.file'
paths=(
  '.config/waybar-hypr'
  '.local/bin/waybar-date-es'
  '.local/bin/waybar-day-month-es'
  '.local/bin/waybar-time-ampm'
  '.local/bin/waybar-watch'
)

for path in "${paths[@]}"; do
  [[ -e "dotfiles/config/profiles/hyprland/$path" ]]
  nix eval --raw "$attr.\"$path\".source" >/dev/null
done

config='dotfiles/config/profiles/hyprland/.config/waybar-hypr/config'
jq -e '.[0]["modules-center"] == ["custom/day_month", "custom/time", "custom/date"]' "$config" >/dev/null
printf '%s\n' 'hypr-waybar-profile: ok'
