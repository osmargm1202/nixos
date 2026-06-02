#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_ROOT="$(mktemp -d)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_eq() {
  local got="$1" want="$2" name="$3"
  [ "$got" = "$want" ] || fail "$name: got '$got', want '$want'"
}

source_installer() {
  ORGMOS_INSTALLER_TEST=1 source "$REPO_DIR/install.sh"
}

make_nixos_dir() {
  local dir="$1"
  mkdir -p "$dir"
  printf '{}\n' > "$dir/hardware-configuration.nix"
}

# Source must not run main; tests call helper functions directly.
source_installer

etc_dir="$TMP_ROOT/etc/nixos"
live_dir="$TMP_ROOT/mnt/etc/nixos"
make_nixos_dir "$live_dir"

NIXOS_DIR_CANDIDATES="$etc_dir:$live_dir"
NIXOS_DIR="/etc/nixos"
NIXOS_DIR_EXPLICIT=false
resolve_nixos_dir
assert_eq "$NIXOS_DIR" "$live_dir" "autodetect selects live generated config when /etc config is missing"
assert_eq "$HARDWARE_PATH" "$live_dir/hardware-configuration.nix" "hardware path follows live dir"
assert_eq "$FLAKE_PATH" "$live_dir/flake.nix" "flake path follows live dir"
assert_eq "$INSTALL_ACTION" "install" "live config uses nixos-install mode"
assert_eq "$(final_command)" "sudo nixos-install --flake $live_dir#default" "live config final command"

explicit_dir="$TMP_ROOT/custom/etc/nixos"
make_nixos_dir "$explicit_dir"
NIXOS_DIR_CANDIDATES="$etc_dir:$live_dir"
NIXOS_DIR="$explicit_dir"
NIXOS_DIR_EXPLICIT=true
resolve_nixos_dir
assert_eq "$NIXOS_DIR" "$explicit_dir" "explicit nixos dir overrides autodetection"
assert_eq "$INSTALL_ACTION" "rebuild" "explicit non-live path uses rebuild mode"
assert_eq "$(final_command)" "sudo nixos-rebuild switch --flake $explicit_dir#default" "explicit non-live final command"

etc_real="$TMP_ROOT/real-etc/nixos"
make_nixos_dir "$etc_real"
NIXOS_DIR_CANDIDATES="$etc_real:$live_dir"
NIXOS_DIR="/etc/nixos"
NIXOS_DIR_EXPLICIT=false
resolve_nixos_dir
assert_eq "$NIXOS_DIR" "$etc_real" "autodetect prefers installed config over live config"
assert_eq "$INSTALL_ACTION" "rebuild" "installed config uses nixos-rebuild mode"

bash -n "$REPO_DIR/install.sh"

echo "PASS: install installer tests"
