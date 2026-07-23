#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
I3="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"
PROFILE="$ROOT/nixos/profiles/i3.nix"
DOTFILES="$ROOT/nixos/common-dotfiles.nix"
BLOCKS="$ROOT/dotfiles/config/profiles/i3/.config/i3blocks/config"
HELPER="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3blocks-status"
LEGACY="$ROOT/dotfiles/config/profiles/i3/.config/i3status"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

grep -Fq 'extraPackages = [ pkgs.i3blocks ];' "$PROFILE" || fail 'i3blocks package missing'
expected='status_command /run/current-system/sw/bin/i3blocks -c "$HOME/.config/i3blocks/config"'
mapfile -t commands < <(grep -E '^[[:space:]]*status_command ' "$I3")
[[ "${#commands[@]}" -eq 1 ]] || fail 'i3bar must declare exactly one status command'
actual="${commands[0]}"
actual="${actual#"${actual%%[![:space:]]*}"}"
[[ "$actual" == "$expected" ]] || fail "unexpected i3blocks command: $actual"
grep -Fq '[time]' "$BLOCKS" || fail 'time block missing'
grep -Fq "LC_TIME=es_DO.UTF-8 date '+%A %d/%m/%Y'" "$HELPER" || fail 'Spanish date format missing'
grep -Fq "LC_TIME=en_US.UTF-8 date '+%I:%M %p'" "$HELPER" || fail '12-hour time format missing'

[ ! -e "$LEGACY" ] || fail 'legacy i3status config must be removed'
! grep -Fq '".config/i3status"' "$DOTFILES" || fail 'legacy i3status config is still deployed'
! grep -Fq 'status_command i3status' "$I3" || fail 'legacy i3status command remains configured'

printf 'PASS: i3blocks preserves Spanish date and 12-hour time formats\n'
