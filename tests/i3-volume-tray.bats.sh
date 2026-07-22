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
grep -Fq 'exec --no-startup-id pasystray' "$CONFIG" ||
  fail 'pasystray must start inside the i3 systray session'
grep -Fq 'tray_output primary' "$CONFIG" || fail 'i3bar primary tray missing'

printf 'PASS: i3 starts a volume control applet in its systray\n'
