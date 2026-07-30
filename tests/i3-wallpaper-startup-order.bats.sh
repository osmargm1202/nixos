#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"
AUTOSTART="$ROOT/dotfiles/config/profiles/i3/.config/autostart/autorandr.desktop"
MONITOR="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-monitor-profile"
WALLPAPER="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-wallpaper"
WRAPPER="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-set-wallpaper"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

grep -Fq 'Hidden=true' "$AUTOSTART" || fail 'packaged Autorandr XDG autostart is not disabled'
if grep -Fq 'Exec=' "$AUTOSTART"; then fail 'disabled Autorandr desktop still launches concurrently'; fi
[[ "$(grep -Fc 'exec --no-startup-id $run i3-monitor-profile --apply' "$CONFIG")" -eq 1 ]] ||
  fail 'i3 must run exactly one serialized monitor/wallpaper restore'
if grep -Fq 'exec --no-startup-id i3-wallpaper --restore' "$CONFIG"; then
  fail 'independent wallpaper startup races Autorandr'
fi
grep -Fq 'i3-wallpaper --restore' "$MONITOR" || fail 'monitor restore does not finish with wallpaper restore'
grep -Fq 'restore_wallpaper' "$MONITOR" || fail 'wallpaper restore is not shared by success/failure paths'
grep -Fq 'state_file="$state_dir/wallpaper"' "$WALLPAPER" || fail 'wallpaper selection is not persistent'
grep -Fq 'exec i3-wallpaper --set-active "$1"' "$WRAPPER" ||
  fail 'Thunar wrapper does not persist the active monitor through i3-wallpaper'

printf 'PASS: i3 serializes monitor restoration before persistent wallpaper application\n'
