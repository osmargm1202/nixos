#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
upstream="${RYOKU_SOURCE:-}"
if [[ -z "$upstream" ]]; then
  upstream="$(RYOKU_TEST_REPO="$ROOT" nix eval --impure --raw --expr \
    '(builtins.getFlake ("path:" + builtins.getEnv "RYOKU_TEST_REPO")).inputs.ryoku.outPath')"
fi
hyprland="${RYOKU_HYPRLAND:-}"
if [[ -z "$hyprland" ]]; then
  hyprland="$(RYOKU_TEST_REPO="$ROOT" nix eval --impure --raw --expr \
    '(builtins.getFlake ("path:" + builtins.getEnv "RYOKU_TEST_REPO")).inputs.ryoku.packages.${builtins.currentSystem}.ryoku-hyprland.outPath')/bin/Hyprland"
fi
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/config/orgm-ryoku" "$tmp/state/orgm-ryoku" "$tmp/home" "$tmp/runtime"
chmod 700 "$tmp/runtime"
cp -a "$upstream/ryoku/hyprland/." "$tmp/config/hypr/"
chmod -R u+w "$tmp/config/hypr"
cp "$ROOT"/dotfiles/config/profiles/ryoku/.config/orgm-ryoku/*.lua "$tmp/config/orgm-ryoku/"
cp "$ROOT"/dotfiles/config/users/osmarg/profiles/ryoku/.config/orgm-ryoku/*.lua \
  "$tmp/config/orgm-ryoku/"
cp "$tmp/config/orgm-ryoku/rebind.lua" "$tmp/config/hypr/modules/rebind.lua"
cp "$tmp/config/orgm-ryoku/user.lua" "$tmp/config/hypr/user.lua"
cp "$tmp/config/orgm-ryoku/keyboard.lua" "$tmp/config/hypr/keyboard.lua"
XDG_CONFIG_HOME="$tmp/config" XDG_STATE_HOME="$tmp/state" \
  "${LUA_BIN:-lua}" "$ROOT/tests/ryoku-shortcuts.lua" "$upstream"
XDG_CONFIG_HOME="$tmp/config" "${LUA_BIN:-lua}" "$ROOT/tests/ryoku-window-rules.lua"
env -u HYPRLAND_INSTANCE_SIGNATURE -u WAYLAND_DISPLAY -u DISPLAY \
  -u GNOME_KEYRING_CONTROL HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/config" \
  XDG_STATE_HOME="$tmp/state" XDG_RUNTIME_DIR="$tmp/runtime" \
  DBUS_SESSION_BUS_ADDRESS="unix:path=$tmp/runtime/no-session-bus" \
  "$hyprland" --verify-config --config "$tmp/config/hypr/hyprland.lua"
