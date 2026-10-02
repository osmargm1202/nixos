#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
upstream="${RYOKU_SOURCE:-}"
if [[ -z "$upstream" ]]; then
  upstream="$(RYOKU_TEST_REPO="$ROOT" nix eval --impure --raw --expr \
    '(builtins.getFlake ("path:" + builtins.getEnv "RYOKU_TEST_REPO")).inputs.ryoku.outPath')"
fi
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/config/orgm-ryoku" "$tmp/config/hypr/modules" "$tmp/state/orgm-ryoku"
cp "$ROOT"/dotfiles/config/profiles/ryoku/.config/orgm-ryoku/*.lua "$tmp/config/orgm-ryoku/"
cp "$ROOT/dotfiles/config/users/osmarg/profiles/hyprland/.config/hypr/lua/keybindings.lua" \
  "$tmp/config/orgm-ryoku/osmarg-keybindings.lua"
cp "$tmp/config/orgm-ryoku/rebind.lua" "$tmp/config/hypr/modules/rebind.lua"
XDG_CONFIG_HOME="$tmp/config" XDG_STATE_HOME="$tmp/state" \
  "${LUA_BIN:-lua}" "$ROOT/tests/ryoku-shortcuts.lua" "$upstream"
grep -Fq 'SUPER + CTRL + ALT + SHIFT' "$tmp/state/orgm-ryoku/shortcuts.tsv"
