#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
I3="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"
HYPR="$ROOT/dotfiles/config/profiles/hyprland/.config/hypr/lua/autostart.lua"
CINNAMON="$ROOT/nixos/profiles/cinnamon.nix"
COMMON="$ROOT/nixos/common.nix"
HYPR_PROFILE="$ROOT/nixos/profiles/hyprland.nix"
HYPR_KDECONNECT_PORTAL="$ROOT/nixos/packages/hypr-kdeconnect-fix.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

grep -Fq 'programs.kdeconnect.enable = true;' "$COMMON" ||
  fail 'KDE Connect must be enabled to open its discovery firewall ports'
grep -Fq 'exec --no-startup-id kdeconnect-indicator' "$I3" ||
  fail 'i3 must start the KDE Connect indicator'
grep -Fq '"kdeconnect-indicator",' "$HYPR" ||
  fail 'Hyprland must start the KDE Connect indicator'
grep -Fq 'xdg.configFile."autostart/kdeconnect-indicator.desktop".text' "$CINNAMON" ||
  fail 'Cinnamon must install the KDE Connect autostart entry'
grep -Fq 'Exec=kdeconnect-indicator' "$CINNAMON" ||
  fail 'Cinnamon autostart entry must launch the KDE Connect indicator'
grep -Fq 'hyprKdeconnectFix = pkgs.callPackage ../packages/hypr-kdeconnect-fix.nix { };' "$HYPR_PROFILE" ||
  fail 'Hyprland must package the KDE Connect RemoteDesktop portal'
grep -Fq 'hyprKdeconnectFix' "$HYPR_PROFILE" ||
  fail 'Hyprland must install the KDE Connect RemoteDesktop portal'
grep -Fq 'hyprland."org.freedesktop.impl.portal.RemoteDesktop" = "hypr-kdeconnect";' "$HYPR_PROFILE" ||
  fail 'Hyprland must route RemoteDesktop to the KDE Connect portal'
grep -Fq 'repo = "hypr-kdeconnect-fix";' "$HYPR_KDECONNECT_PORTAL" ||
  fail 'KDE Connect portal package must use the remote-input bridge source'

printf 'PASS: KDE Connect discovery, indicators and Hyprland remote input are configured\n'
