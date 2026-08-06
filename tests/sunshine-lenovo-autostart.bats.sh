#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HYPR="$ROOT/dotfiles/config/profiles/hyprland/.config/hypr/lua/autostart.lua"
I3="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"
LABWC="$ROOT/dotfiles/config/profiles/labwc/.config/labwc/autostart"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

for configuration in \
  lenovo-hyprland lenovo-i3 lenovo-labwc \
  lenovo-windows-hyprland lenovo-windows-i3 lenovo-windows-labwc
do
  nix eval --json ".#nixosConfigurations.${configuration}.config.services.sunshine" |
    jq -e '.enable and .autoStart and .capSysAdmin and .openFirewall' >/dev/null ||
    fail "${configuration} must enable and autostart Sunshine"
done

grep -Fq 'systemctl --user --quiet start sunshine.service || true' "$HYPR" ||
  fail 'Hyprland must start the Sunshine user service'
grep -Fq 'exec --no-startup-id systemctl --user --quiet start sunshine.service' "$I3" ||
  fail 'i3 must start the Sunshine user service'
grep -Fq 'systemctl --user --quiet start sunshine.service 2>/dev/null || true' "$LABWC" ||
  fail 'Labwc must start the Sunshine user service'

printf '%s\n' 'sunshine-lenovo-autostart: ok'
