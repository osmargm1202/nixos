#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

nix eval --raw "path:$ROOT#nixosConfigurations" --apply '
  systems: let
    original = systems.orgm-i3;
    disabled = original.extendModules {
      modules = [ ({ lib, ... }: {
        orgm.user.programs = lib.mkForce (builtins.filter
          (program: program != "tmux") original.config.orgm.user.programs);
      }) ];
    };
  in disabled.config.home-manager.users.osmarg.home.activation.removeConflictingDotfiles.data
' > "$tmp/cleanup.sh"

home="$tmp/home"
mkdir -p "$home/.config/tmux"
printf 'personal settings\n' > "$home/.config/tmux/custom.conf"
ln -s /nix/store/old-home-manager-files/.tmux.conf "$home/.tmux.conf"
ln -s /nix/store/old-home-manager-files/.config/tmux/plugins.conf "$home/.config/tmux/plugins.conf"
HOME="$home" DRY_RUN_CMD='' bash "$tmp/cleanup.sh"
[[ ! -L "$home/.tmux.conf" ]] || { printf 'FAIL: disabled tmux retained its managed config\n' >&2; exit 1; }
[[ ! -L "$home/.config/tmux/plugins.conf" ]] || { printf 'FAIL: disabled tmux retained managed plugins\n' >&2; exit 1; }
[[ "$(cat "$home/.config/tmux/custom.conf")" == 'personal settings' ]] || { printf 'FAIL: cleanup destroyed unowned tmux files\n' >&2; exit 1; }

printf 'unmanaged tmux config\n' > "$home/.tmux.conf"
HOME="$home" DRY_RUN_CMD='' bash "$tmp/cleanup.sh"
[[ "$(cat "$home/.tmux.conf")" == 'unmanaged tmux config' ]] || { printf 'FAIL: cleanup destroyed an unmanaged regular config\n' >&2; exit 1; }
printf 'PASS: disabling a program removes managed links but preserves personal files\n'
