#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATUS="$ROOT/dotfiles/config/profiles/i3/.config/i3status/config"
I3="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"
DOTFILES="$ROOT/nixos/common-dotfiles.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[ -f "$STATUS" ] || fail 'custom minimal i3status config missing'
mapfile -t orders < <(grep -E '^[[:space:]]*order \+=' "$STATUS")
[ "${#orders[@]}" -eq 2 ] || fail 'i3status must contain only date and time modules'
grep -Fq 'order += "tztime date"' "$STATUS" || fail 'Spanish date module missing'
grep -Fq 'order += "tztime time"' "$STATUS" || fail '12-hour time module missing'
grep -Fq 'locale = "es_DO.UTF-8"' "$STATUS" || fail 'Spanish weekday locale missing'
grep -Fq 'format = "%A %d/%m/%Y"' "$STATUS" || fail 'requested weekday/date format missing'
grep -Fq 'locale = "en_US.UTF-8"' "$STATUS" || fail 'AM/PM locale missing'
grep -Fq 'format = "%I:%M %p"' "$STATUS" || fail 'requested 12-hour AM/PM format missing'
grep -Fq 'status_command i3status' "$I3" || fail 'i3bar must continue using i3status'
grep -Fq 'separator_symbol " · "' "$I3" || fail 'date/time separator missing'
grep -Fq '".config/i3status"' "$DOTFILES" || fail 'i3status config not deployed'

printf 'PASS: i3bar shows only Spanish date and 12-hour time\n'
