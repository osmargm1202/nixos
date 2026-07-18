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
[[ "$(nix eval .#nixosConfigurations.orgm-i3.config.services.getty.autologinUser --raw 2>/dev/null)" == osmarg ]] \
  || fail 'orgm autologin user'
[[ "$(nix eval .#nixosConfigurations.jarq-i3.config.services.getty.autologinUser --raw 2>/dev/null)" == jarq ]] \
  || fail 'jarq autologin user'
grep -q 'i3-startx-attempted' nixos/profiles/i3.nix \
  || fail 'startx loop guard missing'

printf 'PASS: i3 profile tests\n'
