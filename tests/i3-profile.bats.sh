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
for host in orgm lenovo ero jarq; do
  prefix="path:$ROOT#nixosConfigurations.${host}-i3.config"
  [[ "$(nix eval "${prefix}.services.xserver.windowManager.i3.enable" 2>/dev/null)" == true ]] \
    || fail "${host}-i3 must enable i3"
  [[ "$(nix eval --raw "${prefix}.services.displayManager.defaultSession" 2>/dev/null)" == 'none+i3' ]] \
    || fail "${host}-i3 must select the i3 X11 session in SDDM"
  [[ "$(nix eval "${prefix}.services.displayManager.sddm.enable" 2>/dev/null)" == true ]] \
    || fail "${host}-i3 must enable SDDM"
  [[ "$(nix eval --raw "${prefix}.services.displayManager.sddm.theme" 2>/dev/null)" == 'GreenShift' ]] \
    || fail "${host}-i3 must use the GreenShift SDDM theme"
  [[ "$(nix eval "${prefix}.services.displayManager.autoLogin.enable" 2>/dev/null)" == false ]] \
    || fail "${host}-i3 must not autologin"
  [[ "$(nix eval "${prefix}.services.xserver.displayManager.startx.enable" 2>/dev/null)" == false ]] \
    || fail "${host}-i3 must not enable StartX"
done
[[ "$(nix eval --raw "path:$ROOT#nixosConfigurations.orgm-i3.config.services.displayManager.sddm.wayland.compositor" 2>/dev/null)" == 'kwin' ]] \
  || fail 'i3 SDDM must retain the KWin greeter compositor'
[[ "$(nix eval --raw "path:$ROOT#nixosConfigurations.orgm-i3.config.systemd.services.display-manager.environment.KWIN_FORCE_SW_CURSOR" 2>/dev/null)" == '1' ]] \
  || fail 'i3 SDDM must retain the KWin software-cursor workaround'

printf 'PASS: i3 profile tests\n'
