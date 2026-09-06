#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Exercise the evaluated activation only inside a disposable HOME.
activation="$(nix eval --raw "path:$ROOT#nixosConfigurations.orgm-hyprland.config.home-manager.users.osmarg.home.activation.initGeneratedConfigs.data")"
export HOME="$TMP/home" DRY_RUN_CMD=''
mkdir -p "$HOME/.config/gtk-3.0"
printf 'user-owned settings\n' >"$HOME/.config/gtk-3.0/settings.ini"
bash -euc "$activation"
[[ "$(cat "$HOME/.config/gtk-3.0/settings.ini")" == 'user-owned settings' ]]

for path in \
  '.config/gtk-4.0/settings.ini' \
  '.icons/default/index.theme' \
  '.config/kitty/current-theme.conf' \
  '.config/hypr/scheme/current.conf'; do
  [[ -f "$HOME/$path" && ! -L "$HOME/$path" ]]
  printf 'custom runtime value\n' >"$HOME/$path"
done
bash -euc "$activation"
for path in \
  '.config/gtk-4.0/settings.ini' \
  '.icons/default/index.theme' \
  '.config/kitty/current-theme.conf' \
  '.config/hypr/scheme/current.conf'; do
  [[ "$(cat "$HOME/$path")" == 'custom runtime value' ]]
done
printf 'PASS: defaults initialize missing files without overwriting runtime configuration\n'
