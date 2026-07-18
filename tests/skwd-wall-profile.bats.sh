#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLAKE="$ROOT/flake.nix"
PROFILE="$ROOT/nixos/profiles/hyprland.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

grep -Fq 'skwd-wall = {' "$FLAKE" || fail "missing skwd-wall flake input"
grep -Fq 'url = "github:osmargm1202/skwd-wall";' "$FLAKE" || fail "skwd-wall input must use Osmar fork"
grep -Fq 'inputs.skwd-wall.nixosModules.default' "$PROFILE" || fail "Hyprland profile must import Skwd module"
grep -Fq 'programs.skwd-wall.enable = true;' "$PROFILE" || fail "Hyprland profile must enable Skwd"
if grep -Eq '^[[:space:]]+waytrogen([[:space:]]|$)' "$PROFILE"; then
  fail "Hyprland profile must not install Waytrogen"
fi

printf 'PASS: Skwd profile contract\n'
