#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/home/.config"
export XDG_STATE_HOME="$tmp/home/.local/state" DRY_RUN_CMD=''
export XDG_DATA_HOME="$tmp/home/.local/share"
export DBUS_SESSION_BUS_ADDRESS="unix:path=$tmp/no-session-bus"
state="$XDG_STATE_HOME/orgm-ryoku"
mkdir -p "$XDG_CONFIG_HOME/orgm-ryoku" "$XDG_CONFIG_HOME/hypr" "$tmp/original"
cp "$ROOT"/dotfiles/config/profiles/ryoku/.config/orgm-ryoku/*.lua "$XDG_CONFIG_HOME/orgm-ryoku/"
cp "$ROOT"/dotfiles/config/profiles/ryoku/.config/orgm-ryoku/desktop-defaults.json "$XDG_CONFIG_HOME/orgm-ryoku/"
cp "$ROOT"/dotfiles/config/profiles/ryoku/.config/orgm-ryoku/kitty.conf "$XDG_CONFIG_HOME/orgm-ryoku/"
cp "$ROOT"/dotfiles/config/hosts/lenovo/profiles/ryoku/.config/orgm-ryoku/monitors_user.lua "$XDG_CONFIG_HOME/orgm-ryoku/"
mkdir -p "$XDG_CONFIG_HOME/ryoku" "$XDG_CONFIG_HOME/kitty"
printf '%s\n' '{"dock":{"enabled":true,"edge":"bottom","pinned":["kitty","firefox"]}}' > "$XDG_CONFIG_HOME/ryoku/shell.json"
cp "$XDG_CONFIG_HOME/ryoku/shell.json" "$tmp/dock.before.json"
printf 'font_size 15\n' > "$tmp/original/kitty-user.conf"
ln -s "$tmp/original/kitty-user.conf" "$XDG_CONFIG_HOME/kitty/user.conf"
printf 'immutable original\n' > "$tmp/original/user.lua"
ln -s "$tmp/original/user.lua" "$XDG_CONFIG_HOME/hypr/user.lua"
printf 'Nix palette hook\n' > "$tmp/original/matugen-config.toml"
ln -s "$tmp/original/matugen-config.toml" "$XDG_CONFIG_HOME/orgm-ryoku/matugen-config.toml"
# The retired alias may change, but encrypted and passwordless collections stay.
mkdir -p "$XDG_DATA_HOME/keyrings"
printf 'existing encrypted login bytes\n' > "$XDG_DATA_HOME/keyrings/login.keyring"
printf 'existing passwordless collection bytes\n' > "$XDG_DATA_HOME/keyrings/orgm-never-ask.keyring"
printf '%s\n' orgm-never-ask > "$XDG_DATA_HOME/keyrings/default"
bash "$ROOT/nixos/profiles/ryoku/prepare.sh"
[[ ! -L "$XDG_CONFIG_HOME/hypr/user.lua" ]]
[[ ! -L "$XDG_CONFIG_HOME/ryoku/user_edits/matugen/config.toml" ]]
cmp "$tmp/original/matugen-config.toml" "$XDG_CONFIG_HOME/ryoku/user_edits/matugen/config.toml"
[[ ! -L "$XDG_CONFIG_HOME/kitty/user.conf" ]]
grep -Fxq 'font_size 15' "$XDG_CONFIG_HOME/kitty/user.conf"
grep -Fxq 'background_opacity 0.85' "$XDG_CONFIG_HOME/kitty/orgm-ryoku.conf"
[[ "$(cat "$tmp/original/kitty-user.conf")" == 'font_size 15' ]]
cmp "$XDG_CONFIG_HOME/ryoku/shell.json" "$tmp/dock.before.json"
grep -Fq 'disabled = true' "$XDG_CONFIG_HOME/hypr/monitors_user.lua"
printf 'personal monitor layout\n' > "$XDG_CONFIG_HOME/hypr/monitors_user.lua"
[[ -L "$state/user.before-ryoku" ]]
[[ "$(cat "$tmp/original/user.lua")" == 'immutable original' ]]
[[ ! -L "$XDG_CONFIG_HOME/ryoku/user_edits/hypr/modules/rebind.lua" ]]
jq -e '.desktop.appearance.rounding == 12 and .desktop.appearance.borderSize == 0 and .desktop.input.followMouse == 1' "$XDG_CONFIG_HOME/ryoku/desktop.json" > /dev/null
jq -e '.desktop.input.kbLayout == "us,latam" and .desktop.input.kbVariant == "altgr-intl," and .desktop.input.kbOptions == "grp:ctrl_space_toggle"' "$XDG_CONFIG_HOME/ryoku/desktop.json" > /dev/null
printf '%s\n' '{"desktop":{"appearance":{"rounding":18,"borderSize":1},"input":{"followMouse":0}}}' > "$XDG_CONFIG_HOME/ryoku/desktop.json"
[[ "$(readlink "$XDG_CONFIG_HOME/hypr/hypridle.conf")" == ../ryoku/hypridle.conf ]]
printf 'Ryoku generated idle policy\n' > "$XDG_CONFIG_HOME/ryoku/hypridle.conf"
[[ "$(cat "$XDG_CONFIG_HOME/hypr/hypridle.conf")" == 'Ryoku generated idle policy' ]]
# Repeated preparation preserves a pre-existing default-path configuration.
rm "$XDG_CONFIG_HOME/hypr/hypridle.conf"
printf 'personal idle config\n' > "$XDG_CONFIG_HOME/hypr/hypridle.conf"
[[ "$(<"$XDG_DATA_HOME/keyrings/default")" == login ]]
[[ "$(<"$XDG_DATA_HOME/keyrings/login.keyring")" == 'existing encrypted login bytes' ]]
[[ "$(<"$XDG_DATA_HOME/keyrings/orgm-never-ask.keyring")" == 'existing passwordless collection bytes' ]]
printf 'keyboard edited through Ryoku\n' > "$XDG_CONFIG_HOME/hypr/keyboard.lua"
printf 'updated Nix palette hook\n' > "$tmp/original/matugen-config.toml"
bash "$ROOT/nixos/profiles/ryoku/prepare.sh"
cmp "$tmp/original/matugen-config.toml" "$XDG_CONFIG_HOME/ryoku/user_edits/matugen/config.toml"
jq -e '.desktop.appearance.rounding == 18 and .desktop.appearance.borderSize == 1 and .desktop.input.followMouse == 0' "$XDG_CONFIG_HOME/ryoku/desktop.json" > /dev/null
[[ "$(cat "$XDG_CONFIG_HOME/hypr/hypridle.conf")" == 'personal idle config' ]]
[[ "$(cat "$XDG_CONFIG_HOME/hypr/keyboard.lua")" == 'keyboard edited through Ryoku' ]]
[[ "$(cat "$XDG_CONFIG_HOME/hypr/monitors_user.lua")" == 'personal monitor layout' ]]
[[ $(grep -Fxc 'include orgm-ryoku.conf' "$XDG_CONFIG_HOME/kitty/user.conf") -eq 1 ]]
cmp "$XDG_CONFIG_HOME/ryoku/shell.json" "$tmp/dock.before.json"
[[ "$(cat "$state/user.before-ryoku")" == 'immutable original' ]]
# Do not rewrite an unrelated user-selected collection on repeated activation.
printf '%s\n' custom > "$XDG_DATA_HOME/keyrings/default"
bash "$ROOT/nixos/profiles/ryoku/prepare.sh"
[[ "$(<"$XDG_DATA_HOME/keyrings/default")" == custom ]]
# Existing Ryoku settings win when the preferences are first seeded too.
rm "$state/desktop-defaults.seeded"
bash "$ROOT/nixos/profiles/ryoku/prepare.sh"
jq -e '.desktop.appearance.rounding == 18 and .desktop.appearance.borderSize == 1 and .desktop.appearance.roundingPower == 2 and .desktop.input.followMouse == 0' "$XDG_CONFIG_HOME/ryoku/desktop.json" > /dev/null

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
grep -Fxq 'font_size 15' "$XDG_CONFIG_HOME/kitty/user.conf"
! grep -Fq 'include orgm-ryoku.conf' "$XDG_CONFIG_HOME/kitty/user.conf"
[[ ! -e "$XDG_CONFIG_HOME/kitty/orgm-ryoku.conf" ]]
grep -Fxq 'background_opacity 0.85' "${backups[0]}/.config/kitty/orgm-ryoku.conf"
[[ "$(cat "$XDG_CONFIG_HOME/hypr/keyboard.lua")" == 'keyboard edited through Ryoku' ]]
[[ ! -e "$state/active" ]]
# A subsequent activation must leave regular files alone without the marker.
printf 'new personal Kitty settings\n' > "$XDG_CONFIG_HOME/kitty/kitty.conf"
bash "$tmp/cleanup.sh"
[[ "$(cat "$XDG_CONFIG_HOME/kitty/kitty.conf")" == 'new personal Kitty settings' ]]
printf 'PASS: Ryoku transitions preserve original links, runtime edits and unmanaged files\n'
