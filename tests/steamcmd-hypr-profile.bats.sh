#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT/nixos/profiles/hyprland.nix"
DOTFILES="$ROOT/nixos/common-dotfiles.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

grep -Eq '^[[:space:]]+steamcmd([[:space:]]|$)' "$PROFILE" || fail 'steamcmd missing from common Hyprland packages'
grep -Fq '".local/bin/steam-workshop-image"' "$DOTFILES" || fail 'Steam image helper missing from sharedPaths'

cd "$ROOT"
packages="$(nix eval ".#nixosConfigurations.orgm-hyprland.config.environment.systemPackages" --json 2>/dev/null)"
jq -e 'any(.[]; test("-steamcmd-[^/]*$"))' <<< "$packages" >/dev/null \
  || fail 'steamcmd missing from orgm-hyprland closure'

printf 'PASS: SteamCMD available in the Hyprland profile\n'
