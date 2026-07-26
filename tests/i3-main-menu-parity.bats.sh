#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/dotfiles/config/profiles/i3/.local/bin"
MAIN="$BIN/i3-main-menu"
DEVICES="$BIN/i3-devices-menu"
POWER="$BIN/i3-powermenu"
DOTFILES="$ROOT/nixos/common-dotfiles.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[ -x "$DEVICES" ] || fail 'i3-devices-menu missing or not executable'
for helper in i3-main-menu i3-devices-menu i3-powermenu; do
  grep -Fq "\".local/bin/$helper\"" "$DOTFILES" || fail "$helper not deployed"
  bash -n "$BIN/$helper"
done

for entry in Apps Windows Terminal Zen Chromium Files Obsidian Calculator Clipboard SSH Devices Wallpaper Performance Help Power; do
  grep -Fq "$entry" "$MAIN" || fail "main menu entry missing: $entry"
done

grep -Fq 'Devices) exec i3-devices-menu' "$MAIN" || fail 'Devices submenu dispatch missing'
grep -Fq 'Calculator) exec i3-calc' "$MAIN" || fail 'Calculator dispatch missing'
grep -Fq 'Zen) exec i3-zen-new-window' "$MAIN" || fail 'Zen dispatch missing'
grep -Fq 'Wallpaper) exec i3-wallpaper --random' "$MAIN" || fail 'Wallpaper dispatch missing'
grep -Fq 'Help) exec i3-hotkeys' "$MAIN" || fail 'Help dispatch missing'
grep -Fq 'Power) exec xlogout' "$MAIN" || fail 'Power dispatch missing'

for entry in Displays Wi-Fi Bluetooth Audio Keyboard Storage Back; do
  grep -Fq "$entry" "$DEVICES" || fail "devices menu entry missing: $entry"
done
grep -Fq 'Back) exec i3-main-menu' "$DEVICES" || fail 'Devices Back must return to main menu'
grep -Fq 'Cancel) exec i3-main-menu' "$POWER" || fail 'Power Cancel must return to main menu'

printf 'PASS: i3 main menu exposes daily apps, devices, help and power\n'
