#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLAKE="$ROOT/flake.nix"
INVENTORY="$ROOT/configurations.nix"
BUILDER="$ROOT/lib/mk-system.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local needle="$1" file="$2" name="$3"
  grep -Fq -- "$needle" "$file" || fail "$name"
}

assert_not_contains() {
  local needle="$1" file="$2" name="$3"
  if grep -Fq -- "$needle" "$file"; then
    fail "$name"
  fi
}

assert_contains \
  'configurationInventory = import ./configurations.nix;' \
  "$FLAKE" \
  'flake must load explicit configuration inventory'
assert_contains \
  'builtConfigurations =' \
  "$FLAKE" \
  'flake must define built configurations'
assert_contains \
  'builtConfigurations = nixpkgs.lib.mapAttrs (' \
  "$FLAKE" \
  'flake must map inventory specs through mkSystem'
assert_contains \
  '_: systemBuilders.mkSystem' \
  "$FLAKE" \
  'flake must map inventory specs through mkSystem'
assert_contains \
  ') configurationInventory.configurations;' \
  "$FLAKE" \
  'flake must map inventory specs through mkSystem'
assert_contains \
  'nixosConfigurations = builtConfigurations // configurationAliases;' \
  "$FLAKE" \
  'flake must expose built configurations plus explicit aliases'

for old_matrix_entry in \
  'orgm-hyprland = mkHost' \
  'lenovo-hyprland = mkHost' \
  'jarq-hyprland = mkHost' \
  'ero-server ='
do
  assert_not_contains "$old_matrix_entry" "$FLAKE" "matrix entry remains in flake: $old_matrix_entry"
done

for file in "$FLAKE" "$INVENTORY" "$BUILDER"; do
  assert_not_contains 'builtins.readDir' "$file" "directory discovery forbidden in $file"
  assert_not_contains 'importAll' "$file" "recursive imports forbidden in $file"
done

assert_not_contains 'nixos/general.nix' "$FLAKE" 'broken general module path remains in flake'
assert_not_contains 'nixos/general.nix' "$BUILDER" 'broken general module path remains in builder'

printf 'PASS: thin flake architecture\n'
