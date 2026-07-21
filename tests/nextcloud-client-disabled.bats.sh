#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1"
  local file="$2"
  if ! grep -Fq "$pattern" "$file"; then
    fail "missing '$pattern' in $file"
  fi
}

assert_present 'nextcloud-client' "$ROOT/nixos/common.nix"
assert_present 'nextcloud --background' "$ROOT/dotfiles/config/profiles/hyprland/.config/hypr/lua/autostart.lua"
assert_present 'nextcloud --background' "$ROOT/dotfiles/config/profiles/hyprlandqs-caelestia/.config/hypr/lua/autostart.lua"
assert_present 'spawn-at-startup "nextcloud"' "$ROOT/dotfiles/config/profiles/hyprland/.config/niri/00-startup.kdl"
assert_present 'nextcloud --background' "$ROOT/dotfiles/config/profiles/labwc/.config/labwc/autostart"

assert_present 'Nextcloud/Documentos/keys/age.txt' "$ROOT/dotfiles/config/shared/.config/fish/age.fish"
assert_present 'Nextcloud/Documentos/keys/age.txt' "$ROOT/dotfiles/config/hosts/lenovo/.config/fish/age-host.fish"
assert_present 'Nextcloud/Documentos/keys/age.txt' "$ROOT/dotfiles/config/hosts/orgm/.config/fish/age-host.fish"

printf 'PASS: Nextcloud client package and desktop autostarts restored\n'
