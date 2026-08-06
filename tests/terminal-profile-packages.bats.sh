#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

profile_has_zutty() {
  local configuration="$1"
  nix eval --impure --raw --expr "
    let c = (builtins.getFlake (toString ./.)).nixosConfigurations.${configuration};
    in if builtins.elem c.pkgs.zutty c.config.environment.systemPackages then \"present\" else \"absent\"
  "
}

for configuration in lenovo-hyprland lenovo-labwc lenovo-gnome; do
  [[ "$(profile_has_zutty "$configuration")" == absent ]]
done

for configuration in lenovo-i3 cinnamon; do
  [[ "$(profile_has_zutty "$configuration")" == present ]]
done

programs='dotfiles/config/profiles/hyprland/.config/hypr/lua/programs.lua'
keybindings='dotfiles/config/profiles/hyprland/.config/hypr/lua/keybindings.lua'
apps_menu='dotfiles/config/profiles/hyprland/.local/bin/hypr-apps-menu'

! grep -Fq 'zutty-fast' "$programs"
! grep -Fq 'zutty-fast' "$keybindings"
! grep -Fq 'Zutty' "$apps_menu"
grep -Fq 'terminal = "kitty"' "$programs"
grep -Fq "*'Kitty') exec kitty" "$apps_menu"

printf '%s\n' 'terminal-profile-packages: ok'
