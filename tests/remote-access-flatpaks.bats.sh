#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

flatpaks="$(nix eval --json '.#nixosConfigurations.orgm-hyprland.config.services.flatpak.packages')"
for app_id in \
  com.moonlight_stream.Moonlight \
  com.anydesk.Anydesk \
  com.rustdesk.RustDesk; do
  jq -e --arg app_id "$app_id" 'any(.[]; .appId == $app_id)' <<<"$flatpaks" >/dev/null ||
    fail "orgm-hyprland is missing Flatpak $app_id"
done

for profile in orgm-cinnamon orgm-gnome; do
  packages="$(nix eval --json ".#nixosConfigurations.${profile}.config.environment.systemPackages")"
  jq -e 'any(.[]; test("-rofi-[^/]+$"))' <<<"$packages" >/dev/null ||
    fail "$profile is missing Rofi"
done

printf '%s\n' 'remote-access-flatpaks: ok'
