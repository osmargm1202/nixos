#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT/nixos/profiles/i3.nix"
GTK_SETTINGS="$ROOT/dotfiles/config/profiles/i3/.config/gtk-3.0/settings.ini"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

grep -Eq '^[[:space:]]+XCURSOR_SIZE[[:space:]]*=[[:space:]]*"24";' "$PROFILE" \
  || fail 'i3 session must export XCURSOR_SIZE=24'
! grep -Eq '^[[:space:]]+XCURSOR_SIZE[[:space:]]*=[[:space:]]*"0";' "$PROFILE" \
  || fail 'i3 session must not export XCURSOR_SIZE=0'
grep -Fxq 'gtk-cursor-theme-size=24' "$GTK_SETTINGS" \
  || fail 'i3 GTK cursor size must be 24'
! grep -Fxq 'gtk-cursor-theme-size=0' "$GTK_SETTINGS" \
  || fail 'i3 GTK cursor size must not be 0'

printf 'PASS: i3 cursor size is declaratively 24\n'
