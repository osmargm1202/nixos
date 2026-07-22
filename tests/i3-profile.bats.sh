#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

for host in orgm lenovo ero jarq; do
  grep -Eq "^[[:space:]]*${host}-i3[[:space:]]*=[[:space:]]*mkHost" flake.nix \
    || fail "missing ${host}-i3"
  grep -A4 -E "^[[:space:]]*${host}-i3[[:space:]]*=" flake.nix \
    | grep -q 'profile = ./nixos/profiles/i3.nix' \
    || fail "${host}-i3 does not use i3.nix"
done

[[ "$(nix eval .#nixosConfigurations.orgm-i3.config.services.xserver.enable 2>/dev/null)" == true ]] \
  || fail 'Xserver disabled'
[[ "$(nix eval .#nixosConfigurations.orgm-i3.config.services.xserver.displayManager.startx.enable 2>/dev/null)" == true ]] \
  || fail 'startx disabled'
[[ "$(nix eval .#nixosConfigurations.orgm-i3.config.services.xserver.displayManager.startx.generateScript 2>/dev/null)" == true ]] \
  || fail 'xinitrc generation disabled'
for host in orgm lenovo ero jarq; do
  [[ "$(nix eval ".#nixosConfigurations.${host}-i3.config.services.getty.autologinUser" --json 2>/dev/null)" == null ]] \
    || fail "${host}-i3 must require manual TTY login"
done
grep -Fq 'if test (tty) = /dev/tty1; and not set -q DISPLAY' nixos/profiles/i3.nix \
  || fail 'tty1 startx guard missing'
! grep -Fq 'i3-startx-attempted' nixos/profiles/i3.nix \
  || fail 'stale startx marker remains'

printf 'PASS: i3 profile tests\n'
