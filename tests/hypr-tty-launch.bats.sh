#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT/nixos/profiles/hyprland.nix"
STEAM="$ROOT/nixos/gaming/steam.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

! grep -Fq './sddm.nix' "$PROFILE" ||
  fail 'Hyprland must not import SDDM'
! grep -Fq 'services.getty.autologinUser' "$PROFILE" ||
  fail 'Hyprland must not enable global TTY autologin'
grep -Fq 'programs.bash.loginShellInit = lib.mkAfter' "$PROFILE" ||
  fail 'Hyprland must use a login-shell TTY launch guard'
grep -Fq '"$(tty)" = /dev/tty1' "$PROFILE" ||
  fail 'tty1 must be the Hyprland launch console'
grep -Fq 'exec start-hyprland' "$PROFILE" ||
  fail 'tty1 login must exec the Hyprland session launcher'
grep -Fq 'pgrep -x gamescope >/dev/null' "$PROFILE" ||
  fail 'tty1 must reject Hyprland while Gamescope owns DRM'
! grep -Fq 'systemd.services."autovt@tty6"' "$PROFILE" ||
  fail 'Hyprland must not own the Steam TTY service'
! grep -Fq '"$(tty)" = /dev/tty6' "$PROFILE" ||
  fail 'Hyprland must not own the Steam TTY launcher'
grep -Fq 'programs.bash.loginShellInit = lib.mkAfter' "$STEAM" ||
  fail 'Steam must install the login-shell TTY launcher for every Steam-enabled profile'
grep -Fq 'systemd.services."autovt@tty6" = {' "$STEAM" ||
  fail 'Steam must configure tty6 autologin for every Steam-enabled profile'
! grep -Fq 'wantedBy = [ "getty.target" ];' "$STEAM" ||
  fail 'Steam TTY must not start at boot beside the desktop session'
grep -Fq '${pkgs.util-linux}/sbin/agetty --autologin ${userName} --noclear %I $TERM' "$STEAM" ||
  fail 'tty6 must autologin the configured user'
grep -Fq '"$(tty)" = /dev/tty6' "$STEAM" ||
  fail 'tty6 must be the Steam launch console'
grep -Fq 'gamescopeCommand = if nvidiaGameOffload then "nvidia-game gamescope" else "gamescope";' "$STEAM" ||
  fail 'TTY6 must offload Gamescope on Lenovo PRIME'
grep -Fq '__NV_PRIME_RENDER_OFFLOAD_PROVIDER = "NVIDIA-G0";' "$STEAM" ||
  fail 'Steam must select the configured NVIDIA PRIME provider'
grep -Fq 'exec ${gamescopeCommand} -e -- steam -gamepadui' "$STEAM" ||
  fail 'tty6 must run Big Picture inside Gamescope'

printf 'PASS: Steam-enabled profiles get a dedicated Gaming Mode TTY\n'
