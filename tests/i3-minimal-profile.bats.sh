#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT/nixos/profiles/i3.nix"
DOTFILES_MODULE="$ROOT/nixos/common-dotfiles.nix"
MANIFEST="$ROOT/dotfiles/config/dotfiles.json"
I3_ROOT="$ROOT/dotfiles/config/profiles/i3"
I3_CONFIG="$I3_ROOT/.config/i3/config"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

for forbidden in conky waybar 'hypr-' polybar eww i3blocks; do
  if grep -Eqi "$forbidden" "$PROFILE" "$I3_CONFIG"; then
    fail "i3 profile still references $forbidden"
  fi
  if grep -REqi "$forbidden" "$I3_ROOT"; then
    fail "i3 dotfile tree still references $forbidden"
  fi
done

grep -Eq '^[[:space:]]+i3status[[:space:]]*$' "$PROFILE" ||
  fail 'NixOS i3 integration must install i3status'
grep -Fq 'bar {' "$I3_CONFIG" || fail 'native i3bar is missing'
grep -Fq 'status_command i3status' "$I3_CONFIG" || fail 'native i3bar must use default i3status'
! grep -Eq 'i3bar_command|tray_output|font pango:.*bar' "$I3_CONFIG" ||
  fail 'i3bar must not carry custom bar settings'

for path in .config/conky .config/picom .config/polybar; do
  [ ! -e "$I3_ROOT/$path" ] || fail "$path must be removed from i3 dotfiles"
  if grep -Fq "\"$path\"" "$DOTFILES_MODULE"; then
    fail "$path must not be deployed for i3"
  fi
done

for helper in i3-polybar i3-polybar-theme i3-gh0stzk-theme i3-polybar-launch i3-status-battery i3-status-cpu-temp i3-status-gpu-temp; do
  [ ! -e "$I3_ROOT/.local/bin/$helper" ] || fail "$helper must be removed"
  if grep -Fq "\".local/bin/$helper\"" "$DOTFILES_MODULE"; then
    fail "$helper must not be deployed"
  fi
done

jq -e '
  all(.shared.paths[]; . != ".config/conky" and . != ".config/picom" and . != ".config/polybar")
' "$MANIFEST" >/dev/null || fail 'obsolete i3 desktop paths remain in dotfiles manifest'

printf 'PASS: i3 uses only its native i3bar with default i3status\n'
