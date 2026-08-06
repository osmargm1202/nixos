#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

plugin="$(nix eval --raw --impure --expr '
  let flake = builtins.getFlake (toString ./.) ;
  in flake.nixosConfigurations.lenovo-windows-hyprland.pkgs.callPackage ./nixos/packages/tmux-pane-tree.nix { }
')"
grep -Fq 'source-file ${tmuxPaneTree}/share/tmux-plugins/tmux-pane-tree/tmux-pane-tree.tmux' "$repo_dir/nixos/common-dotfiles.nix"
entrypoint="$plugin/share/tmux-plugins/tmux-pane-tree/tmux-pane-tree.tmux"
[[ -f "$entrypoint" ]]

config="$(mktemp)"
socket="tmux-pane-tree-$$"
trap 'tmux -L "$socket" kill-server 2>/dev/null || true; rm -f "$config"' EXIT
cat >"$config" <<EOF
source-file $repo_dir/dotfiles/config/shared/.tmux.conf
source-file $entrypoint
EOF

tmux -L "$socket" -f "$config" new-session -d -s pane-tree
bindings="$(tmux -L "$socket" list-keys -T prefix)"
[[ "$bindings" == *'toggle-sidebar.sh'* ]]
[[ "$bindings" == *'focus-sidebar.sh'* ]]
clock_binding="$(tmux -L "$socket" list-keys -T prefix C-t)"
[[ "$clock_binding" == *'clock-mode'* ]]
status_right="$(tmux -L "$socket" show-options -gv status-right)"
[[ "$status_right" == *"󰥔"* ]]
grep -Fq '󰥔#[fg=${thm_blue},bg=${thm_gray}' "$repo_dir/dotfiles/config/shared/.tmux.conf"
[[ "$status_right" == *"$HOME/.local/bin/tmux-spanish-date"* ]]
date_helper="$repo_dir/dotfiles/config/shared/.local/bin/tmux-spanish-date"
[[ -x "$date_helper" ]]
date_output="$("$date_helper")"
[[ "$date_output" =~ [0-9]{2}:[0-9]{2}[[:space:]](AM|PM)[[:space:]]·[[:space:]][0-9]{2}/[0-9]{2}/[0-9]{4}[[:space:]]·[[:space:]](lunes|martes|miércoles|jueves|viernes|sábado|domingo),[[:space:]][0-9]{2}[[:space:]]de[[:space:]](enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre)[[:space:]]de[[:space:]][0-9]{4} ]]

mode_keys="$(tmux -L "$socket" show-window-options -gv mode-keys)"
[[ "$mode_keys" == "vi" ]]
copy_bindings="$(tmux -L "$socket" list-keys -T copy-mode-vi)"
[[ "$copy_bindings" == *"page-up"* ]]
[[ "$copy_bindings" == *"page-down"* ]]
[[ "$copy_bindings" == *"search-forward"* ]]
[[ "$copy_bindings" == *"search-backward"* ]]
[[ "$copy_bindings" == *"begin-selection"* ]]
[[ "$copy_bindings" == *"copy-selection-and-cancel"* ]]


printf '%s\n' 'tmux-pane-tree: ok'
