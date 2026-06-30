#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail() { echo "FAIL: $*" >&2; exit 1; }
assert_contains() { grep -Fq "$2" "$1" || fail "expected $2 in $1"; }

for cfg in "$ROOT/config/shared/.config/waybar/config" "$ROOT/config/shared/.config/waybar-hypr/config"; do
  assert_contains "$cfg" '"custom/usb_devices"'
  assert_contains "$cfg" '"exec": "hypr-usb-menu status"'
  assert_contains "$cfg" '"on-click": "hypr-usb-menu open"'
  assert_contains "$cfg" '"on-click-right": "hypr-usb-menu nickname"'
  assert_contains "$cfg" '"custom/nixclean"'
  assert_contains "$cfg" '"on-click": "kitty --class nixclean -e fish -lc'
done

for css in "$ROOT/config/shared/.config/waybar/style.css" "$ROOT/config/shared/.config/waybar-hypr/style.css"; do
  assert_contains "$css" '#custom-usb_devices'
  assert_contains "$css" '#custom-nixclean'
done

assert_contains "$ROOT/config/dotfiles.json" '".local/bin/hypr-usb-menu"'

echo "waybar usb nixclean test passed"
