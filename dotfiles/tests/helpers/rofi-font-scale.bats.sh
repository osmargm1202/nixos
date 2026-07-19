#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ROFI="$ROOT/config/profiles/hyprland/.config/rofi"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

grep -Fq 'font: "JetBrains Mono Regular 15.6";' "$ROFI/config.rasi" ||
  fail "general Rofi font must be scaled from 13 to 15.6"
grep -Fq 'font: "JetBrainsMono Nerd Font 14.4";' "$ROFI/hypr-menu.rasi" ||
  fail "Hypr menu font must be scaled from 12 to 14.4"

if grep -Eq '^[[:space:]]*(dpi|scale):' "$ROFI/config.rasi" "$ROFI/hypr-menu.rasi"; then
  fail "font scaling must not change Rofi geometry through DPI or global scale"
fi

printf 'PASS: Rofi fonts scaled 1.2x without geometry scaling\n'
