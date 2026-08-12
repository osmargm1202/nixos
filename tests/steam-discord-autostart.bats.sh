#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
I3="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"
HYPR="$ROOT/dotfiles/config/profiles/hyprland/.config/hypr/lua/autostart.lua"
LABWC="$ROOT/dotfiles/config/profiles/labwc/.config/labwc/autostart"
CONFIGURATIONS="$ROOT/configurations.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

# All named host/profile combinations consume these profile-level startup files.
for target in orgm-hyprland orgm-i3 orgm-labwc lenovo-hyprland lenovo-i3 lenovo-labwc; do
  grep -Fq "$target" "$CONFIGURATIONS" || fail "configuration inventory missing $target"
done

# The Discord wrapper supplies the established WebRTC policy and Flatpak bridge.
grep -Fq "exec discord --start-minimized" "$I3" || fail 'i3 must start Discord minimized'
grep -Fq '"hypr-start-discord",' "$HYPR" || fail 'Hyprland must use the Discord startup helper'
grep -Fq 'exec discord --start-minimized' "$LABWC" || fail 'Labwc must start Discord minimized after DMS'

# Steam is optional outside ORGM/Lenovo, so unavailable installations remain harmless.
for config in "$I3" "$HYPR" "$LABWC"; do
  grep -Fq 'steam -silent' "$config" || fail "Steam silent startup missing from $config"
  grep -Fq 'command -v steam' "$config" || fail "Steam startup must tolerate absent Steam in $config"
done

grep -Fq 'until pgrep -u "$USER" -x dms' "$LABWC" ||
  fail 'Labwc Discord must wait for the DMS tray'

printf 'PASS: Steam and Discord start minimized in i3, Hyprland, and Labwc\n'
