#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
I3="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"
PROFILE="$ROOT/nixos/profiles/i3.nix"
DOTFILES="$ROOT/nixos/common-dotfiles.nix"
LEGACY="$ROOT/dotfiles/config/profiles/i3/.config/i3status"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

grep -Fq '(bumblebee-status.override { plugins = p: [ p.shortcut p.date p.time ]; })' "$PROFILE" ||
  fail 'Bumblebee Status must include caffeine shortcut, date and time modules'
expected='status_command bumblebee-status -m shortcut date time -p shortcut.cmds="i3-caffeine-toggle" shortcut.labels="" date.format="%A %d/%m/%Y" date.locale="es_DO.UTF-8" time.format="%I:%M %p" time.locale="en_US.UTF-8" -i i3-clean -t nord-powerline'
mapfile -t commands < <(grep -E '^[[:space:]]*status_command ' "$I3")
[[ "${#commands[@]}" -eq 1 ]] || fail 'i3bar must declare exactly one status command'
actual="${commands[0]}"
actual="${actual#"${actual%%[![:space:]]*}"}"
[[ "$actual" == "$expected" ]] || fail "unexpected Bumblebee command: $actual"

[ ! -e "$LEGACY" ] || fail 'legacy i3status config must be removed'
if grep -Fq '".config/i3status"' "$DOTFILES"; then
  fail 'legacy i3status config is still deployed'
fi
if grep -Fq 'i3status' "$PROFILE"; then
  fail 'legacy i3status package remains installed'
fi
if grep -Fq 'status_command i3status' "$I3"; then
  fail 'legacy i3status command remains configured'
fi

printf 'PASS: Bumblebee Status uses Nord Powerline with preserved date/time formats\n'
