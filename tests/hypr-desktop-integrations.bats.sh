#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

profile='nixos/profiles/hyprland/hyprland.nix'
tray_helper='dotfiles/config/users/osmarg/profiles/hyprland/.local/bin/hypr-tray-applets'
host_dir='dotfiles/config/hosts/orgm/shared'

grep -Fxq '    pasystray' "$profile"
grep -Fxq 'pasystray &' "$tray_helper"

grep -Fxq '    nwg-look' "$profile"
for launcher in omp claude-code opencode pi codex reddit; do
  desktop="$host_dir/.local/share/applications/$launcher.desktop"
  [[ -f "$desktop" ]]
  desktop-file-validate "$desktop"
 done
grep -Fxq 'Exec=kitty "--title=Claude Code" --class=orgm-claude-code bash -lc "exec claude"' \
  "$host_dir/.local/share/applications/claude-code.desktop"

for icon in omp opencode reddit; do
  icon_path="$host_dir/.local/share/icons/$icon.svg"
  [[ -s "$icon_path" ]]
 done

printf '%s\n' 'hypr-desktop-integrations: ok'
