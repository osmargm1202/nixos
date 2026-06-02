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

assert_file_contains() {
  local file="$1" want="$2" name="$3"
  grep -qF -- "$want" "$file" || {
    echo "--- $file ---" >&2
    cat "$file" >&2 2>/dev/null || true
    fail "$name expected: $want"
  }
}

assert_file_not_contains() {
  local file="$1" want="$2" name="$3"
  if grep -qF -- "$want" "$file"; then
    echo "--- $file ---" >&2
    cat "$file" >&2 2>/dev/null || true
    fail "$name must not contain: $want"
  fi
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

server_dir="$TMP_ROOT/server/etc/nixos"
make_nixos_dir "$server_dir"
NIXOS_DIR="$server_dir"
NIXOS_DIR_EXPLICIT=true
DRY_RUN=false
SELECTED_PROFILE="server"
SELECTED_HOSTNAME="serverbox"
FLAKE_PATH="$server_dir/flake.nix"
HARDWARE_PATH="$server_dir/hardware-configuration.nix"
refresh_nixos_paths
printf 'y\n' | write_flake > "$TMP_ROOT/server.out"
assert_file_contains "$FLAKE_PATH" "orgmos.lib.mkServerHost" "server flake uses mkServerHost"
assert_file_contains "$FLAKE_PATH" 'hostName = "serverbox";' "server flake includes hostname"
assert_file_not_contains "$FLAKE_PATH" "mkGeneralHost" "server flake skips desktop host helper"
assert_file_not_contains "$FLAKE_PATH" "nixosModules.gpu" "server flake skips GPU modules"
assert_file_not_contains "$FLAKE_PATH" "nixosModules.kernel" "server flake skips kernel modules"

desktop_dir="$TMP_ROOT/desktop/etc/nixos"
make_nixos_dir "$desktop_dir"
NIXOS_DIR="$desktop_dir"
NIXOS_DIR_EXPLICIT=true
DRY_RUN=false
SELECTED_PROFILE="hyprland"
SELECTED_HOSTNAME="deskbox"
SELECTED_GPU="intel"
SELECTED_GPU_MODULE="orgmos.nixosModules.gpu.intel"
SELECTED_KERNEL="zen"
SELECTED_KERNEL_MODULE="orgmos.nixosModules.kernel.zen"
FLAKE_PATH="$desktop_dir/flake.nix"
HARDWARE_PATH="$desktop_dir/hardware-configuration.nix"
refresh_nixos_paths
printf 'y\n' | write_flake > "$TMP_ROOT/desktop.out"
assert_file_contains "$FLAKE_PATH" "orgmos.lib.mkGeneralHost" "desktop flake keeps mkGeneralHost"
assert_file_contains "$FLAKE_PATH" "orgmos.nixosModules.gpu.intel" "desktop flake includes GPU module"
assert_file_contains "$FLAKE_PATH" "orgmos.nixosModules.kernel.zen" "desktop flake includes kernel module"

bash -n "$REPO_DIR/install.sh"

echo "PASS: install installer tests"
