#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
config="$root/config/profiles/hyprland/.config/waybar-hypr/config"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[ -f "$config" ] || fail "missing Waybar-Hypr config"
[ "$(grep -Fc '"custom/wallpaper": {' "$config")" -eq 2 ] || fail "expected two wallpaper module definitions"
[ "$(grep -Fc '"on-click": "skwd wall toggle"' "$config")" -eq 2 ] || fail "both wallpaper modules should toggle Skwd"
[ "$(grep -Fc '"tooltip-format": "Selector de wallpapers"' "$config")" -eq 2 ] || fail "both wallpaper tooltips should describe the selector"
if grep -Eq 'waytrogen|hypr-wallpaper-picker' "$config"; then
  fail "Waybar wallpaper modules must not expose a legacy picker action"
fi

printf 'PASS: Waybar-Hypr wallpaper action configured\n'
