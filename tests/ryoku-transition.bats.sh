#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/home/.config"
export XDG_STATE_HOME="$tmp/home/.local/state" DRY_RUN_CMD=''
state="$XDG_STATE_HOME/orgm-ryoku"
mkdir -p "$XDG_CONFIG_HOME/orgm-ryoku" "$XDG_CONFIG_HOME/hypr" "$tmp/original"
cp "$ROOT"/dotfiles/config/profiles/ryoku/.config/orgm-ryoku/*.lua "$XDG_CONFIG_HOME/orgm-ryoku/"
printf 'immutable original\n' > "$tmp/original/user.lua"
ln -s "$tmp/original/user.lua" "$XDG_CONFIG_HOME/hypr/user.lua"
bash "$ROOT/nixos/profiles/ryoku/prepare.sh"
[[ ! -L "$XDG_CONFIG_HOME/hypr/user.lua" ]]
[[ -L "$state/user.before-ryoku" ]]
[[ "$(cat "$tmp/original/user.lua")" == 'immutable original' ]]
[[ ! -L "$XDG_CONFIG_HOME/ryoku/user_edits/hypr/modules/rebind.lua" ]]
printf 'keyboard edited through Ryoku\n' > "$XDG_CONFIG_HOME/hypr/keyboard.lua"
bash "$ROOT/nixos/profiles/ryoku/prepare.sh"
[[ "$(cat "$XDG_CONFIG_HOME/hypr/keyboard.lua")" == 'keyboard edited through Ryoku' ]]
[[ "$(cat "$state/user.before-ryoku")" == 'immutable original' ]]

# Exercise the actual Home Manager activation for the profile we return to.
if [[ -n "${RYOKU_RETURN_CLEANUP:-}" ]]; then
  cp "$RYOKU_RETURN_CLEANUP" "$tmp/cleanup.sh"
else
  nix eval --raw "path:$ROOT#nixosConfigurations.lenovo-hyprland.config.home-manager.users.osmarg.home.activation.removeConflictingDotfiles.data" > "$tmp/cleanup.sh"
fi
mkdir -p "$XDG_CONFIG_HOME/kitty"
printf 'Ryoku Kitty settings\n' > "$XDG_CONFIG_HOME/kitty/kitty.conf"
printf 'Ryoku compositor settings\n' > "$XDG_CONFIG_HOME/hypr/hyprland.lua"
printf 'personal unmanaged settings\n' > "$XDG_CONFIG_HOME/kitty/custom.conf"
bash "$tmp/cleanup.sh"
backups=("$state"/return-*)
[[ ${#backups[@]} -eq 1 && -d "${backups[0]}" ]]
[[ "$(cat "${backups[0]}/.config/kitty/kitty.conf")" == 'Ryoku Kitty settings' ]]
[[ "$(cat "${backups[0]}/.config/hypr/hyprland.lua")" == 'Ryoku compositor settings' ]]
[[ "$(cat "$XDG_CONFIG_HOME/kitty/custom.conf")" == 'personal unmanaged settings' ]]
[[ "$(cat "$XDG_CONFIG_HOME/hypr/keyboard.lua")" == 'keyboard edited through Ryoku' ]]
[[ ! -e "$state/active" ]]
# A subsequent activation must leave regular files alone without the marker.
printf 'new personal Kitty settings\n' > "$XDG_CONFIG_HOME/kitty/kitty.conf"
bash "$tmp/cleanup.sh"
[[ "$(cat "$XDG_CONFIG_HOME/kitty/kitty.conf")" == 'new personal Kitty settings' ]]
printf 'PASS: Ryoku transitions preserve original links, runtime edits and unmanaged files\n'
