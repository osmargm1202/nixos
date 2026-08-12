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
  fail 'Hyprland must not own a separate Steam TTY service'
! grep -Fq '"$(tty)" = /dev/tty6' "$PROFILE" ||
  fail 'Hyprland must not own a separate Steam TTY launcher'
grep -Fq 'options.orgm.gaming.gamescopeTty1.enable' "$STEAM" ||
  fail 'Steam must expose a specialization-controlled tty1 Gaming Mode'
grep -Fq 'config.orgm.gaming.gamescopeTty1.enable' "$STEAM" ||
  fail 'Steam tty1 Gaming Mode must be opt-in'
grep -Fq 'programs.bash.loginShellInit = lib.mkForce' "$STEAM" ||
  fail 'Gaming Mode must replace the desktop tty1 launcher'
grep -Fq 'systemd.services = {' "$STEAM" ||
  fail 'Gaming Mode must configure the tty1 getty aliases'
grep -Fq '"getty@tty1".serviceConfig.ExecStart' "$STEAM" ||
  fail 'Gaming Mode must configure the tty1 getty instance'
grep -Fq '"autovt@tty1".serviceConfig.ExecStart' "$STEAM" ||
  fail 'Gaming Mode must configure the tty1 boot alias'
grep -Fq '${pkgs.util-linux}/sbin/agetty --autologin ${userName} --noclear %I $TERM' "$STEAM" ||
  fail 'Gaming Mode tty1 must autologin the configured user'
grep -Fq '"$(tty)" = /dev/tty1' "$STEAM" ||
  fail 'Gaming Mode must start from tty1'
! grep -Fq '/dev/tty6' "$STEAM" ||
  fail 'Gaming Mode must not reserve tty6'
grep -Fq 'gamescopeCommand = if nvidiaGameOffload then "nvidia-game gamescope" else "gamescope";' "$STEAM" ||
  fail 'Gaming Mode must offload Gamescope on Lenovo PRIME'
grep -Fq '__NV_PRIME_RENDER_OFFLOAD_PROVIDER = "NVIDIA-G0";' "$STEAM" ||
  fail 'Gaming Mode must select the configured NVIDIA PRIME provider'
grep -Fq 'exec ${gamescopeCommand} -e -- steam -gamepadui' "$STEAM" ||
  fail 'Gaming Mode must run Big Picture inside Gamescope'

printf 'PASS: Steam-enabled profiles get a dedicated Gaming Mode TTY\n'
