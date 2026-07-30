#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
I3="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"
HYPR="$ROOT/dotfiles/config/profiles/hyprland/.config/hypr/lua/autostart.lua"
CINNAMON="$ROOT/nixos/profiles/cinnamon.nix"
COMMON="$ROOT/nixos/common.nix"
I3_PROFILE="$ROOT/nixos/profiles/i3.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

grep -Fq 'kdePackages.kdeconnect-kde' "$COMMON" ||
  fail 'KDE Connect package must be installed for desktop profiles'
grep -Fq '++ lib.optionals isMinimalDesktop [ pkgs.kdePackages.kdeconnect-kde ];' "$I3_PROFILE" ||
  fail 'minimal i3 must install the KDE Connect indicator'
grep -Fq 'exec --no-startup-id kdeconnect-indicator' "$I3" ||
  fail 'i3 must start the KDE Connect indicator'
grep -Fq '"kdeconnect-indicator",' "$HYPR" ||
  fail 'Hyprland must start the KDE Connect indicator'
grep -Fq 'xdg.configFile."autostart/kdeconnect-indicator.desktop".text' "$CINNAMON" ||
  fail 'Cinnamon must install the KDE Connect autostart entry'
grep -Fq 'Exec=kdeconnect-indicator' "$CINNAMON" ||
  fail 'Cinnamon autostart entry must launch the KDE Connect indicator'

printf 'PASS: KDE Connect indicator autostarts in i3, Hyprland and Cinnamon\n'
