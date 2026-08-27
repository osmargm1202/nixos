#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLAKE="$ROOT/flake.nix"
INVENTORY="$ROOT/configurations.nix"
BUILDER="$ROOT/lib/mk-system.nix"
HOSTS="$ROOT/nixos/hosts.nix"
COMMON="$ROOT/nixos/common.nix"
TERMINAL="$ROOT/nixos/terminal.nix"
SERVER="$ROOT/nixos/server.nix"
ORGM_HOST="$ROOT/nixos/hosts/orgm/ms-7d43.nix"
ZEROTIER="$ROOT/nixos/hosts/orgm/zerotier.nix"

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
  'flake-parts = {' \
  "$FLAKE" \
  'flake must declare flake-parts input'
assert_contains \
  'inputs.nixpkgs-lib.follows = "nixpkgs";' \
  "$FLAKE" \
  'flake-parts nixpkgs-lib must follow root nixpkgs'
assert_contains \
  'flake-parts.lib.mkFlake { inherit inputs; } {' \
  "$FLAKE" \
  'flake must use flake-parts mkFlake'
assert_contains \
  'systems = [ "x86_64-linux" ];' \
  "$FLAKE" \
  'flake-parts must expose the supported system'
assert_contains \
  'flake =' \
  "$FLAKE" \
  'host outputs must be defined in flake-parts flake block'
assert_contains \
  'hostSystem = "x86_64-linux";' \
  "$FLAKE" \
  'NixOS builder must use an explicit host system'
assert_contains \
  'system = hostSystem;' \
  "$FLAKE" \
  'NixOS builder must receive the explicit host system'
assert_contains \
  'configurationInventory = import ./configurations.nix;' \
  "$FLAKE" \
  'flake must load explicit configuration inventory'
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
  'flake block must expose built configurations plus explicit aliases'
assert_contains \
  'perSystem =' \
  "$FLAKE" \
  'platform outputs must be defined in perSystem'
assert_contains \
  'formatter = pkgs.nixfmt-rfc-style;' \
  "$FLAKE" \
  'perSystem must provide the formatter'
assert_contains \
  'packages = {' \
  "$FLAKE" \
  'perSystem must provide packages'
assert_contains \
  'devShells.default = pkgsDev.mkShell {' \
  "$FLAKE" \
  'perSystem must provide the default development shell'
for role_module in "$COMMON" "$TERMINAL" "$SERVER"; do
  assert_contains './hosts.nix' "$role_module" "host registry missing from $role_module"
done
assert_contains 'inherit inputs userName hostName;' "$BUILDER" \
  'host registry must receive the configuration hostname'
assert_contains './hosts/orgm/zerotier.nix' "$HOSTS" \
  'ZeroTier must remain an ORGM host module'
assert_not_contains 'zerotier.nix' "$INVENTORY" \
  'ZeroTier must not be selected by role configurations'
assert_not_contains '../../deskflow.nix' "$ORGM_HOST" \
  'Deskflow must stay outside ORGM base hardware'
assert_contains '172.18.0.251 vilserver1' "$HOSTS" \
  'vilserver1 must be shared by every host role'
assert_not_contains 'networking.extraHosts' "$ZEROTIER" \
  'ZeroTier must not own shared host aliases'

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
