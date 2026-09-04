#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
common="$root/nixos/common.nix"
dotfiles_module="$root/nixos/common-dotfiles.nix"
profile="$root/nixos/profiles/hyprland.nix"
hypr="$root/dotfiles/config/profiles/hyprland"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

mime_default="$(nix eval --json '.#nixosConfigurations.orgm-hyprland.config.xdg.mime.defaultApplications."inode/directory"')"
[[ "$mime_default" == '"org.gnome.Nautilus.desktop"' ]] ||
  fail "Hyprland inode/directory default is $mime_default"

packages="$(nix eval --json --apply 'packages: map (package: package.name) packages' '.#nixosConfigurations.orgm-hyprland.config.environment.systemPackages')"
printf '%s' "$packages" | jq -e 'any(.[]; startswith("nautilus-")) and any(.[]; startswith("totem-")) and any(.[]; startswith("mpvpaper-")) and all(.[]; test("hyprfm"; "i") | not)' >/dev/null ||
  fail 'Hyprland packages must include Nautilus, Totem and mpvpaper, and exclude HyprFM'

grep -Fq 'if profileName == "hyprland" then "org.gnome.Nautilus.desktop" else "yazi.desktop"' "$common" ||
  fail 'shared declarative MIME handler does not branch to Nautilus in Hyprland'
grep -Fq 'xdg-mime default ${if profileName == "hyprland" then "org.gnome.Nautilus.desktop" else "yazi.desktop"} inode/directory' "$dotfiles_module" ||
  fail 'shared Home Manager activation does not branch to Nautilus in Hyprland'
grep -Fq 'xdg-mime default org.gnome.Nautilus.desktop inode/directory' "$profile" ||
  fail 'Hyprland Home Manager activation does not set Nautilus'
! grep -Eq 'hyprFM|hyprfm|HyprFM' "$profile" "$common" "$dotfiles_module" ||
  fail 'HyprFM remains in declarative Hyprland configuration'
[[ ! -e "$root/nixos/packages/hyprfm.nix" ]] || fail 'HyprFM package derivation remains'
[[ ! -e "$hypr/.config/hyprfm/config.toml" ]] || fail 'HyprFM configuration remains'

grep -Fxq '  fileManager = "nautilus --new-window",' "$hypr/.config/hypr/lua/programs.lua" ||
  fail 'Win+E file manager is not Nautilus'
grep -Fxq 'exec nautilus --new-window "$dir"' "$hypr/.local/bin/hypr-rofi-open-file-dir" ||
  fail 'directory launcher is not Nautilus'
grep -Fxq "  *'Files') exec nautilus --new-window ;;" "$hypr/.local/bin/hypr-tools-menu" ||
  fail 'tools menu Files action is not Nautilus'
grep -Fq "entry 'Win+E' 'Archivos' 'nautilus --new-window'" "$hypr/.local/bin/hypr-keybindings-help" ||
  fail 'keybinding help does not show Nautilus'
grep -Fq 'class = "^(org.gnome.Nautilus)$"' "$hypr/.config/hypr/lua/windows-workspaces.lua" ||
  fail 'Nautilus visual rule is missing'
! grep -Eq 'hyprFM|hyprfm|HyprFM' "$hypr/.config/hypr/lua/programs.lua" "$hypr/.local/bin/hypr-rofi-open-file-dir" "$hypr/.local/bin/hypr-tools-menu" "$hypr/.local/bin/hypr-keybindings-help" "$hypr/.config/hypr/lua/windows-workspaces.lua" ||
  fail 'a HyprFM launcher or visual rule remains'

printf '%s\n' 'hypr-nautilus-default: ok'
