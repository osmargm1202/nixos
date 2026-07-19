#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CLASSIC="$ROOT/config/profiles/hyprland/.config/hypr/lua/keybindings.lua"
CAELESTIA="$ROOT/config/profiles/hyprlandqs-caelestia/.config/hypr/lua/keybindings.lua"
HELP="$ROOT/config/profiles/hyprland/.local/bin/hypr-keybindings-help"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

for file in "$CLASSIC" "$CAELESTIA"; do
  grep -Fq 'mainMod .. " + ALT + left"' "$file" || fail "Alt+Left missing in $file"
  grep -Fq 'resizeactive -40 0' "$file" || fail "shrink width missing in $file"
  grep -Fq 'mainMod .. " + ALT + right"' "$file" || fail "Alt+Right missing in $file"
  grep -Fq 'resizeactive 40 0' "$file" || fail "grow width missing in $file"
  grep -Fq 'mainMod .. " + ALT + up"' "$file" || fail "Alt+Up missing in $file"
  grep -Fq 'resizeactive 0 -40' "$file" || fail "shrink height missing in $file"
  grep -Fq 'mainMod .. " + ALT + down"' "$file" || fail "Alt+Down missing in $file"
  grep -Fq 'resizeactive 0 40' "$file" || fail "grow height missing in $file"
done

grep -Fq 'Win+Alt+flechas' "$HELP" || fail 'new arrow resize help missing'
grep -Fq 'Win+Ctrl+- / +=' "$HELP" || fail 'width resize help must include Ctrl'
grep -Fq 'Win+Shift+- / +=' "$HELP" || fail 'height resize help must include Shift'

printf 'PASS: Hyprland resize bindings\n'
