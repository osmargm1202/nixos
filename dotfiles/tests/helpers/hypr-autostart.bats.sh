#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AUTOSTART="$ROOT/config/profiles/hyprland/.config/hypr/lua/autostart.lua"

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

[ -f "$AUTOSTART" ] || fail "missing autostart.lua"

if grep -Eq '^\s*--\s*".*waybar-watch ~/.config/waybar-hypr' "$AUTOSTART"; then
	fail "Waybar autostart must not be commented"
fi

grep -Eq '"sh -lc '\''\$HOME/\.local/bin/hypr-display-targets ensure && \$HOME/\.local/bin/waybar-watch ~/\.config/waybar-hypr'\''' "$AUTOSTART" ||
	fail "Waybar autostart should ensure display targets and run waybar-watch ~/.config/waybar-hypr"

if grep -Eq 'hypr-skwd-wall-start|skwd-daemon|waytrogen|hypr-random-wallpaper|hypr-current-wallpaper' "$AUTOSTART"; then
	fail "Hyprland autostart must not launch a wallpaper daemon or helper"
fi

echo "hypr autostart checks passed"
