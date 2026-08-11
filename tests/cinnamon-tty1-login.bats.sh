#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

for configuration in cinnamon orgm-cinnamon lenovo-windows-cinnamon; do
  prefix=".#nixosConfigurations.${configuration}.config"

  [[ "$(nix eval --json "${prefix}.services.displayManager.sddm.enable" 2>/dev/null)" == false ]] \
    || fail "${configuration} must disable SDDM"
  [[ "$(nix eval --json "${prefix}.services.xserver.displayManager.startx.enable" 2>/dev/null)" == true ]] \
    || fail "${configuration} must enable startx"
  [[ "$(nix eval --json "${prefix}.services.xserver.displayManager.startx.generateScript" 2>/dev/null)" == false ]] \
    || fail "${configuration} must not generate xinitrc"
  [[ "$(nix eval --json "${prefix}.services.getty.autologinUser" 2>/dev/null)" == null ]] \
    || fail "${configuration} must require manual TTY login"
done

profile=nixos/profiles/cinnamon.nix

! grep -Fq './sddm.nix' "$profile" \
  || fail 'Cinnamon profile must not import SDDM'
! grep -Fq 'autologin' "$profile" \
  || fail 'Cinnamon profile must not configure autologin'
grep -Fq 'if [[ $- == *i* && "$USER" = "${userName}" && "$(tty)" = /dev/tty1 && -z "$DISPLAY" && -z "$WAYLAND_DISPLAY" ]]; then' "$profile" \
  || fail 'interactive tty1 Cinnamon launcher guard missing'
grep -Fq 'exec ${pkgs.xinit}/bin/startx ${cinnamonXSession}' "$profile" \
  || fail 'Cinnamon startx launcher missing'
for variable in \
  'export DESKTOP_SESSION=cinnamon' \
  'export XDG_CURRENT_DESKTOP=X-Cinnamon' \
  'export XDG_SESSION_DESKTOP=cinnamon' \
  'export XDG_SESSION_TYPE=x11'; do
  grep -Fq "$variable" "$profile" \
    || fail "Cinnamon session variable missing: ${variable}"
done
grep -Fq 'config.services.displayManager.sessionData.wrapper' "$profile" \
  || fail 'NixOS session wrapper missing'
grep -Fq 'cinnamon-session-cinnamon' "$profile" \
  || fail 'Cinnamon X11 session command missing'
grep -Fq 'systemd.services."getty@tty1" = {' "$profile" \
  || fail 'tty1 service override missing'
grep -Fq 'wantedBy = [ "getty.target" ];' "$profile" \
  || fail 'tty1 getty target dependency missing'
grep -Fq 'after = [ "home-manager-${userName}.service" ];' "$profile" \
  || fail 'tty1 Home Manager ordering missing'
grep -Fq 'wants = [ "home-manager-${userName}.service" ];' "$profile" \
  || fail 'tty1 Home Manager soft dependency missing'

printf 'PASS: Cinnamon tty1 login tests\n'
