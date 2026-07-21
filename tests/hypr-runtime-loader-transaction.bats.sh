#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HYPRLAND="$ROOT/dotfiles/config/profiles/hyprland/.config/hypr/hyprland.lua"
MONITORS="$ROOT/dotfiles/config/profiles/hyprland/.config/hypr/lua/monitors.lua"
WORKSPACES="$ROOT/dotfiles/config/profiles/hyprland/.config/hypr/lua/runtime-workspaces.lua"
DOTFILES_MODULE="$ROOT/nixos/common-dotfiles.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

if grep -Fq 'require("lua.runtime-workspaces")' "$HYPRLAND"; then
  fail 'live hyprland.lua must not require a newly deployed module before Home Manager switch'
fi

[ ! -e "$WORKSPACES" ] ||
  fail 'runtime workspace loading must live in an already-deployed Lua module'

if grep -Fq '".config/hypr/lua/runtime-workspaces.lua"' "$DOTFILES_MODULE"; then
  fail 'Home Manager must not need a new loader symlink for runtime workspaces'
fi

grep -Fq 'local workspace_path = home .. "/.config/hypr/workspaces.lua"' "$MONITORS" ||
  fail 'existing monitor module must locate the NWG runtime workspace file'
grep -Fq 'dofile(workspace_path)' "$MONITORS" ||
  fail 'existing monitor module must load the NWG runtime workspace file'

printf 'PASS: live Hyprland config never depends on a not-yet-deployed Lua module\n'
