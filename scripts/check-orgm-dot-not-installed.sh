#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
failed=0

if grep -nE '^\s*orgmDot\b|orgmDot\s*=\s*pkgs\.callPackage .*orgm-dot\.nix' "$root/nixos/common.nix"; then
  echo "FAIL: nixos/common.nix still installs or defines orgmDot" >&2
  failed=1
fi

if grep -nE '^\s*orgmDot\b|orgmDot\s*=\s*pkgs\.callPackage .*orgm-dot\.nix' "$root/nixos/profiles/hyprland.nix"; then
  echo "FAIL: nixos/profiles/hyprland.nix still installs or defines orgmDot" >&2
  failed=1
fi

if ! grep -q './common-dotfiles.nix' "$root/nixos/common.nix"; then
  echo "FAIL: nixos/common.nix does not import ./common-dotfiles.nix" >&2
  failed=1
fi

if [ "$failed" -ne 0 ]; then
  exit 1
fi

echo "OK: common-dotfiles imported and orgmDot not installed for sync"
