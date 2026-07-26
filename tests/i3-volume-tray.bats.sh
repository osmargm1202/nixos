#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT/nixos/profiles/i3.nix"
CONFIG="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

grep -Eq '^[[:space:]]+pasystray[[:space:]]*$' "$PROFILE" ||
  fail 'PipeWire/PulseAudio-compatible pasystray package missing'
if grep -Fq 'exec --no-startup-id pasystray' "$CONFIG"; then
  fail 'explicit pasystray duplicates its packaged XDG autostart'
fi
grep -Fq 'bar {' "$CONFIG" || fail 'native i3bar missing'
grep -Fq 'status_command i3status' "$CONFIG" || fail 'i3bar must run i3status'
! grep -Fqi 'polybar' "$PROFILE" "$CONFIG" || fail 'Polybar remains enabled'

printf 'PASS: i3bar hosts the standard system tray and i3status\n'
