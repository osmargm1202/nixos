#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AUTOSTART="$ROOT/config/shared/.config/hypr/lua/autostart.lua"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[ -f "$AUTOSTART" ] || fail "missing autostart.lua"

if grep -Eq '^\s*--\s*".*waybar-watch ~/.config/waybar-hypr' "$AUTOSTART"; then
  fail "Waybar autostart must not be commented"
fi

grep -Eq '"sh -lc '\''\$HOME/\.local/bin/hypr-display-targets ensure && \$HOME/\.local/bin/waybar-watch ~/\.config/waybar-hypr'\''' "$AUTOSTART" || \
  fail "Waybar autostart should ensure display targets and run waybar-watch ~/.config/waybar-hypr"

grep -Eq '"sh -lc '\''.*orgm-wallpaper daemon.*'\''' "$AUTOSTART" || \
  fail "Wallpaper daemon should start from Hyprland autostart so previous wallpaper is restored"

echo "hypr autostart checks passed"
