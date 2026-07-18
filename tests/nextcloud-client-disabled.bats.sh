#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_absent() {
  local pattern="$1"
  local file="$2"
  if grep -Fq "$pattern" "$file"; then
    fail "unexpected '$pattern' in $file"
  fi
}

assert_absent 'nextcloud-client' "$ROOT/nixos/common.nix"
assert_absent 'nextcloud --background' "$ROOT/dotfiles/config/profiles/hyprland/.config/hypr/lua/autostart.lua"
assert_absent 'nextcloud --background' "$ROOT/dotfiles/config/profiles/hyprlandqs-caelestia/.config/hypr/lua/autostart.lua"
assert_absent 'spawn-at-startup "nextcloud"' "$ROOT/dotfiles/config/profiles/hyprland/.config/niri/00-startup.kdl"
assert_absent 'nextcloud --background' "$ROOT/dotfiles/config/profiles/labwc/.config/labwc/autostart"

grep -Fq 'Nextcloud/Documentos/keys/age.txt' "$ROOT/dotfiles/config/shared/.config/fish/age.fish" || fail "shared AGE Nextcloud path must remain"
grep -Fq 'Nextcloud/Documentos/keys/age.txt' "$ROOT/dotfiles/config/hosts/lenovo/.config/fish/age-host.fish" || fail "Lenovo AGE Nextcloud path must remain"
grep -Fq 'Nextcloud/Documentos/keys/age.txt' "$ROOT/dotfiles/config/hosts/orgm/.config/fish/age-host.fish" || fail "orgm AGE Nextcloud path must remain"

printf 'PASS: Nextcloud client package and autostarts disabled\n'
