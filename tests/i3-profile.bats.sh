#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

for host in orgm lenovo ero jarq; do
  label="$(nix eval --raw "path:$ROOT#nixosConfigurations.${host}-i3.config.system.nixos.label" 2>/dev/null)"
  [[ "$label" == 'i3' ]] || fail "${host}-i3 does not evaluate the i3 profile"
done

[[ "$(nix eval "path:$ROOT#nixosConfigurations.orgm-i3.config.services.xserver.enable" 2>/dev/null)" == true ]] \
  || fail 'Xserver disabled'
[[ "$(nix eval "path:$ROOT#nixosConfigurations.orgm-i3.config.services.xserver.displayManager.startx.enable" 2>/dev/null)" == true ]] \
  || fail 'startx disabled'
[[ "$(nix eval "path:$ROOT#nixosConfigurations.orgm-i3.config.services.xserver.displayManager.startx.generateScript" 2>/dev/null)" == true ]] \
  || fail 'xinitrc generation disabled'
for host in orgm lenovo ero jarq; do
  [[ "$(nix eval "path:$ROOT#nixosConfigurations.${host}-i3.config.services.getty.autologinUser" --json 2>/dev/null)" == null ]] \
    || fail "${host}-i3 must require manual TTY login"
done

printf 'PASS: i3 profile tests\n'
