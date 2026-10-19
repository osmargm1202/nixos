#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT/nixos/profiles/hyprland/hyprland.nix"
AUTOSTART="$ROOT/dotfiles/config/users/osmarg/profiles/hyprland/.config/hypr/lua/autostart.lua"
WAYBAR="$ROOT/dotfiles/config/users/osmarg/profiles/hyprland/.config/waybar-hypr/config"
HELPER="$ROOT/dotfiles/config/users/osmarg/profiles/hyprland/.local/bin/hypr-tray-applets"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

for package in blueman networkmanagerapplet; do
  grep -Eq "^[[:space:]]+$package[[:space:]]*$" "$PROFILE" ||
    fail "Hyprland must install $package for its tray applet"
done

# Nextcloud comes from the user's application selection, not the desktop.
! grep -Eq '^[[:space:]]+nextcloud-client[[:space:]]*$' "$PROFILE" ||
  fail 'the desktop must not reinstall a deselected Nextcloud client'
envy_helper="$ROOT/dotfiles/config/hosts/envy/profiles/hyprland/.local/bin/hypr-tray-applets"
! grep -Eq 'tailscale systray|syncthingtray|nextcloud --background' "$envy_helper" ||
  fail 'Envy must retain its retired synchronization trays'
bash -n "$envy_helper"
! grep -Eq 'tailscale systray|syncthingtray' "$HELPER" || fail 'ORGM synchronization/VPN must not launch tray clients'

grep -Fq '"hypr-tray-applets",' "$AUTOSTART" ||
  fail 'Hyprland must start applets through the session-ready helper'
for command in 'nm-applet --indicator' blueman-applet 'nextcloud --background'; do
  grep -Fq "$command" "$HELPER" ||
    fail "tray helper must start $command"
done
! grep -Fq '"nm-applet --indicator",' "$AUTOSTART" ||
  fail 'tray applets must not race the graphical session import'
import_line="$(grep -n -F 'hypr-session-import-env' "$HELPER" | cut -d: -f1)"
applet_line="$(grep -n -F 'nm-applet --indicator' "$HELPER" | cut -d: -f1)"
[[ "$import_line" -lt "$applet_line" ]] ||
  fail 'tray helper must import session variables before applets'

jq -e '.["modules-right"] | index("tray") != null' "$WAYBAR" >/dev/null ||
  fail 'Waybar must expose a tray for session applets'

printf 'PASS: Hyprland starts NetworkManager, Bluetooth, and Nextcloud tray applets\n'
