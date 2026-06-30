#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
style="$root/config/shared/.config/waybar-hypr/style.css"
icons_dir="$root/config/shared/.config/waybar-hypr/icons"

custom_buttons=(
  theme_toggle
  usb_devices
  nixclean
  hardware_fetch
  pi_status
  headset_reconnect
  logout_menu
)

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[ -f "$style" ] || fail "missing style.css"

if grep -q 'background-color: rgba(2, 10, 24, 0.78);' "$style"; then
  fail "bar surface should be theme-generated, not hardcoded in style.css"
fi
grep -q 'border: 2px solid rgba(56, 213, 255, 0.42);' "$style" || fail "bar should use 2px sky-blue border"
python3 - "$style" <<'PY' || fail "bar corners should match Hyprland rounding 12px"
import re, sys
content = open(sys.argv[1], encoding='utf-8').read()
match = re.search(r'window\.top_bar#waybar,\s*window\.bottom_bar#waybar\s*\{(?P<body>.*?)\n\}', content, re.S)
if not match or 'border-radius: 12px;' not in match.group('body'):
    raise SystemExit(1)
PY
grep -q 'margin-left": 12' "$root/config/shared/.config/waybar-hypr/config" || fail "Waybar should keep Hyprland-like side gap"
grep -q 'margin-right": 12' "$root/config/shared/.config/waybar-hypr/config" || fail "Waybar should keep Hyprland-like side gap"
grep -q '"on-click": "orgm-wallpaper random-static"' "$root/config/shared/.config/waybar-hypr/config" || fail "wallpaper icon left click should use the active orgm-wallpaper backend"
grep -q '"on-click-right": "orgm-wallpaper pick"' "$root/config/shared/.config/waybar-hypr/config" || fail "wallpaper icon right click should open picker"
grep -q '"tooltip-format": "Wallpaper aleatorio"' "$root/config/shared/.config/waybar-hypr/config" || fail "wallpaper icon tooltip should describe random behavior"
if grep -q '"on-click": "hypr-random-wallpaper next"' "$root/config/shared/.config/waybar-hypr/config"; then
  fail "wallpaper icon left click should not use old hyprpaper helper"
fi
if grep -q 'background-image: url("textura' "$style"; then
  fail "bar style should not use texture background"
fi
if grep -q 'border-left: 2px solid @panel_border\|border-right: 2px solid @panel_border' "$style"; then
  fail "top-right/internal dividers should be removed"
fi

for button in "${custom_buttons[@]}"; do
  icon="$icons_dir/${button}.svg"
  light_icon="$icons_dir/light/${button}.svg"
  [ -f "$icon" ] || fail "missing icon $icon"
  [ -f "$light_icon" ] || fail "missing light icon $light_icon"
  grep -q "#custom-${button}" "$style" || fail "missing CSS selector for custom/$button"
  grep -q "background-image: url(\"icons/${button}.svg\")" "$style" || fail "missing CSS background image for custom/$button"
  grep -q '<svg' "$icon" || fail "$icon is not SVG"
  if grep -q '<rect x="2" y="2" width="28" height="28"' "$icon" "$light_icon"; then
    fail "custom icons should not include a frame rectangle"
  fi
  grep -q '#60a5fa\|#3b82f6' "$icon" || fail "$icon should use sky-blue dark-mode strokes"
  grep -q '#003f8c\|#0057d9' "$light_icon" || fail "$light_icon should use dark blue light-mode strokes"
done

grep -q '>NixOS<' "$icons_dir/nixclean.svg" || fail "nixclean icon should say NixOS"

echo "PASS: Waybar-Hypr custom icons configured"
