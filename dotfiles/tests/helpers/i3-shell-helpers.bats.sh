#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
I3="$ROOT/config/profiles/i3/.config/i3/config"
ROFI="$ROOT/config/profiles/i3/.config/rofi/config.rasi"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

grep -q 'exec --no-startup-id i3-polybar-launch' "$I3" || fail 'polybar launcher missing'
grep -q 'exec --no-startup-id i3-wallpaper-random --restore' "$I3" || fail 'wallpaper restore missing'
grep -q 'exec --no-startup-id clipmenud' "$I3" || fail 'clipmenud missing'
grep -q 'exec --no-startup-id xss-lock' "$I3" || fail 'xss-lock missing'
! grep -Eq 'hypr-|xwinwrap|Videos/wallpapers/1\.mp4' "$I3" || fail 'nonportable command remains'
grep -q 'terminal: "kitty"' "$ROFI" || fail 'Rofi terminal is not Kitty'
grep -q 'modi: "drun,run,window,ssh,calc"' "$ROFI" || fail 'Rofi modes incomplete'

printf 'PASS: i3 shell helper tests\n'
