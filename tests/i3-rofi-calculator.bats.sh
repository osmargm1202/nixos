#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT/nixos/profiles/i3.nix"
CONFIG="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"
ROFI="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-rofi"
CALC="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-calc"
DOTFILES="$ROOT/nixos/common-dotfiles.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

grep -Fq '(rofi.override { plugins = [ rofi-calc ]; })' "$PROFILE" ||
  fail 'Rofi must include the calculator plugin in its wrapped executable'
[ -x "$CALC" ] || fail 'i3-calc helper missing or not executable'
grep -Fq 'rofi -show calc -modes calc' "$CALC" ||
  fail 'i3-calc must use the Rofi 2 calculator mode'
grep -Fq 'bindsym $mod+c exec --no-startup-id i3-calc' "$CONFIG" ||
  fail 'Mod+C must invoke i3-calc'
grep -Fq '".local/bin/i3-calc"' "$DOTFILES" ||
  fail 'i3-calc is not deployed'

if grep -Eq '(^|[[:space:]])-lines([[:space:]]|$)' "$ROFI"; then
  fail 'i3-rofi still uses removed Rofi 2 -lines option'
fi
grep -Fq 'listview { lines:' "$ROFI" ||
  fail 'i3-rofi must set list length through a Rasi override'

bash -n "$CALC" "$ROFI"
printf 'PASS: wrapped Rofi provides calculator mode and current menu sizing\n'
