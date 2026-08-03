#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT/nixos/profiles/hyprland.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

! grep -Fq './sddm.nix' "$PROFILE" ||
  fail 'Hyprland must not import SDDM'
! grep -Fq 'services.getty.autologinUser' "$PROFILE" ||
  fail 'Hyprland must not enable global TTY autologin'
grep -Fq 'programs.bash.loginShellInit = lib.mkAfter (' "$PROFILE" ||
  fail 'Hyprland must use login-shell TTY launch guards'
grep -Fq '"$(tty)" = /dev/tty1' "$PROFILE" ||
  fail 'tty1 must be the Hyprland launch console'
grep -Fq 'exec start-hyprland' "$PROFILE" ||
  fail 'tty1 login must exec the Hyprland session launcher'
grep -Fq 'pgrep -x gamescope >/dev/null' "$PROFILE" ||
  fail 'tty1 must reject Hyprland while Gamescope owns DRM'
grep -Fq 'systemd.services."autovt@tty6" = lib.mkIf config.programs.steam.enable' "$PROFILE" ||
  fail 'tty6 autologin must be limited to Steam-enabled hosts and activated on demand'
! grep -Fq 'wantedBy = [ "getty.target" ];' "$PROFILE" ||
  fail 'Steam TTY must not start at boot beside Hyprland'
grep -Fq '${pkgs.util-linux}/sbin/agetty --autologin ${userName} --noclear %I $TERM' "$PROFILE" ||
  fail 'tty6 must autologin the configured user'
grep -Fq '"$(tty)" = /dev/tty6' "$PROFILE" ||
  fail 'tty6 must be the Steam launch console'
grep -Fq 'exec gamescope -e -- steam -gamepadui' "$PROFILE" ||
  fail 'tty6 must run Big Picture inside Gamescope'
grep -Fq 'pgrep -x Hyprland >/dev/null' "$PROFILE" ||
  fail 'tty6 must reject Gamescope while Hyprland owns DRM'

printf 'PASS: Hyprland and Steam launch from dedicated TTYs\n'
