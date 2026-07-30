#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/dotfiles/config/profiles/i3/.local/bin"
CONFIG="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"
ROFI_DIR="$ROOT/dotfiles/config/profiles/i3/.config/rofi"
THEME="$ROFI_DIR/i3-menu.rasi"
MENU="$BIN/i3-main-menu"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[ -f "$THEME" ] || fail 'neutral i3 Rofi theme missing'
grep -Fq '@import "orgm-current.rasi"' "$THEME" || fail 'i3 Rofi theme does not use current palette'
grep -Fq 'theme="$HOME/.config/rofi/i3-menu.rasi"' "$BIN/i3-rofi" || fail 'i3-rofi does not force parity theme'
grep -Fq 'font: "JetBrainsMono Nerd Font 12"' "$BIN/i3-rofi" || fail 'i3-rofi font override differs from Hyprland'
grep -Fq 'element-icon { size: 32px; }' "$BIN/i3-rofi" || fail 'i3-rofi icon sizing differs from Hyprland'
grep -Fq 'listview { lines: 13; }' "$BIN/i3-rofi" || fail 'launcher/window/calc line count differs from Hyprland'
grep -Fq 'set $launcher $run i3-rofi --drun' "$CONFIG" || fail 'Mod+Space does not use themed Rofi launcher'
grep -Fq 'bindsym Mod1+Tab exec --no-startup-id $run i3-rofi --window' "$CONFIG" || fail 'Alt+Tab window selector is not themed'
grep -Fq 'Apps) exec i3-rofi --drun' "$MENU" || fail 'Apps menu bypasses themed Rofi'
grep -Fq 'Windows) exec i3-rofi --window' "$MENU" || fail 'Windows menu bypasses themed Rofi'

grep -Fq 'bindsym $mod+Mod1+space exec --no-startup-id $run i3-main-menu' "$CONFIG" ||
  fail 'Win+Alt+Space system menu binding missing'
grep -Fq 'bindsym $mod+F12 exec --no-startup-id $run i3-main-menu' "$CONFIG" ||
  fail 'system menu fallback binding missing'
if grep -Rqi 'hypr-menu' "$ROFI_DIR"; then
  fail 'i3 must use neutral theme naming, not hypr-menu'
fi

bash -n "$BIN/i3-rofi"

printf 'PASS: i3 uses the shared Rofi theme without a separate browser helper\n'
