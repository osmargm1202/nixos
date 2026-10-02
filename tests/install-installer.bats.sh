#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

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
cd "$REPO_DIR"

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
assert_eq "$(final_command)" "sudo nixos-install --root /mnt --flake path:$live_dir#default" "live config final command"

explicit_dir="$TMP_ROOT/custom/etc/nixos"
make_nixos_dir "$explicit_dir"
NIXOS_DIR_CANDIDATES="$etc_dir:$live_dir"
NIXOS_DIR="$explicit_dir"
NIXOS_DIR_EXPLICIT=true
resolve_nixos_dir
assert_eq "$NIXOS_DIR" "$explicit_dir" "explicit nixos dir overrides autodetection"
assert_eq "$INSTALL_ACTION" "rebuild" "explicit non-live path uses rebuild mode"
assert_eq "$(final_command)" "sudo nixos-rebuild switch --flake path:$explicit_dir#default" "explicit non-live final command"

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
assert_file_not_contains "$FLAKE_PATH" "/nixos/hardware/gpu/" "server flake skips GPU modules"
assert_file_not_contains "$FLAKE_PATH" "/nixos/hardware/kernel/" "server flake skips kernel modules"
assert_file_contains "$FLAKE_PATH" 'userName = "osmarg";' "server selects a user configuration"

desktop_dir="$TMP_ROOT/desktop/etc/nixos"
make_nixos_dir "$desktop_dir"
NIXOS_DIR="$desktop_dir"
NIXOS_DIR_EXPLICIT=true
DRY_RUN=false
SELECTED_PROFILE="hyprland"
SELECTED_USER="jarq"
SELECTED_HOSTNAME="deskbox"
SELECTED_GPU="intel"
SELECTED_GPU_MODULE='(orgmos.outPath + "/nixos/hardware/gpu/intel.nix")'
SELECTED_KERNEL="zen"
SELECTED_KERNEL_MODULE='(orgmos.outPath + "/nixos/hardware/kernel/zen.nix")'
FLAKE_PATH="$desktop_dir/flake.nix"
HARDWARE_PATH="$desktop_dir/hardware-configuration.nix"
refresh_nixos_paths
printf 'y\n' | write_flake > "$TMP_ROOT/desktop.out"
assert_file_contains "$FLAKE_PATH" "orgmos.lib.mkGeneralHost" "desktop flake keeps mkGeneralHost"
assert_file_contains "$FLAKE_PATH" 'orgmos.outPath + "/nixos/hardware/gpu/intel.nix"' "desktop flake includes GPU module"
assert_file_contains "$FLAKE_PATH" 'orgmos.outPath + "/nixos/hardware/kernel/zen.nix"' "desktop flake includes kernel module"
assert_file_contains "$FLAKE_PATH" 'userName = "jarq";' "desktop uses selected user's applications"
assert_file_not_contains "$FLAKE_PATH" "qylock" "desktop skips removed theme module"

printf '{"version":7}\n' > "$NIXOS_DIR/flake.lock"
cp "$FLAKE_PATH" "$TMP_ROOT/previous-flake"
printf 'y\n' | write_flake > "$TMP_ROOT/rewrite.out"
flake_backups=("$FLAKE_PATH".backup.*)
lock_backups=("$NIXOS_DIR/flake.lock".backup.*)
cmp "${flake_backups[0]}" "$TMP_ROOT/previous-flake"
cmp "${lock_backups[0]}" "$NIXOS_DIR/flake.lock"

# Ensure the menu agrees with the actual repository inventory.
expected_profiles="$(nix-instantiate --eval --strict --expr 'builtins.concatStringsSep " " (builtins.attrNames (import ./configurations.nix).profiles)' --json | tr -d '"')"
actual_profiles="$(printf '%s\n' "${profiles[@]}" | sed '/^server$/d; /^terminal$/d' | sort | paste -sd ' ')"
assert_eq "$actual_profiles" "$expected_profiles" "desktop menu matches configuration inventory"
for user in "${users[@]}"; do
  [ -f "$REPO_DIR/nixos/users/$user.nix" ] || fail "missing user module: $user"
done
(
  SELECTED_PROFILE=ryoku
  SELECTED_USER=jarq
  choose_user <<< 1 > "$TMP_ROOT/ryoku-user.out"
  assert_eq "$SELECTED_USER" osmarg "Ryoku only offers its supported user"
)

# A reconfiguration must never reach disk setup, even when /mnt is absent.
(
  REQUESTED_ACTION=rebuild
  refresh_nixos_paths
  auto_partition() { fail "partitioning called in rebuild mode"; }
  read_prompt() { fail "partition prompt shown in rebuild mode"; }
  maybe_auto_partition
)

# Explicit install mode accepts a custom target and never selects the ISO's /etc.
(
  NIXOS_DIR_EXPLICIT=false
  parse_args --root "$TMP_ROOT/target"
  choose_operation
  assert_eq "$INSTALL_ACTION" install "custom root implies installation"
  assert_eq "$NIXOS_DIR" "$TMP_ROOT/target/etc/nixos" "target configuration path"
)
if (parse_args --root /mnt/..) >/dev/null 2>&1; then
  fail "target root must not resolve to the running system root"
fi

# Dry runs leave the generated hardware (including LUKS declarations) untouched.
printf '{ boot.initrd.luks.devices.cryptroot.device = "/dev/disk/by-uuid/example"; }\n' > "$HARDWARE_PATH"
cp "$HARDWARE_PATH" "$TMP_ROOT/hardware-before"
cp "$FLAKE_PATH" "$TMP_ROOT/flake-before"
DRY_RUN=true
write_flake > "$TMP_ROOT/dry-run.out"
cmp "$HARDWARE_PATH" "$TMP_ROOT/hardware-before"
cmp "$FLAKE_PATH" "$TMP_ROOT/flake-before"
assert_file_contains "$TMP_ROOT/dry-run.out" "Dry run: not writing" "dry run reports no write"

# Exercise UEFI and BIOS generation with firmware detection mocked.
(
  INSTALL_ACTION=install
  detect_firmware() { FIRMWARE=uefi; }
  configure_bootloader
  assert_eq "$FIRMWARE" uefi "UEFI firmware"
  [[ "$INSTALL_BOOT_MODULE" == *'systemd-boot.enable = lib.mkForce true'* ]] || fail "UEFI bootloader"
  detect_firmware() { FIRMWARE=bios; }
  BOOT_DISK=/dev/vda
  configure_bootloader
  [[ "$INSTALL_BOOT_MODULE" == *'grub.devices = lib.mkForce [ "/dev/vda" ]'* ]] || fail "BIOS boot disk"
  DRY_RUN=false
  printf 'y\n' | write_flake > "$TMP_ROOT/bios.out"
  assert_file_contains "$FLAKE_PATH" 'grub.enable = lib.mkForce true;' "BIOS flake uses GRUB"
  assert_file_contains "$FLAKE_PATH" 'programs.nh.flake = lib.mkForce "path:/etc/nixos#default";' "installed nh points to target config"
)
nix-instantiate --parse "$FLAKE_PATH" >/dev/null

# Nix strings must preserve literal quotes, backslashes and interpolation syntax.
literal='path:/tmp/a"b\c${literal}'
encoded="$(nix_string "$literal")"
decoded="$(nix-instantiate --eval --strict --expr "$encoded" --json | python3 -c 'import json,sys; print(json.load(sys.stdin))')"
assert_eq "$decoded" "$literal" "Nix string escaping"

# Verify execution order and the login-password step without invoking real tools.
(
  INSTALL_ACTION=install
  INSTALL_ROOT="$TMP_ROOT/target"
  SELECTED_USER=jarq
  as_root() { printf '%s\n' "$*" >> "$TMP_ROOT/action.log"; }
  run_selected_action > "$TMP_ROOT/action.out"
  assert_file_contains "$TMP_ROOT/action.log" 'flake update orgmos' "refresh obsolete repository lock before evaluation"
  assert_file_contains "$TMP_ROOT/action.log" 'nix --extra-experimental-features nix-command flakes eval' "evaluate before install"
  assert_file_contains "$TMP_ROOT/action.log" "nixos-install --root $INSTALL_ROOT --flake path:$NIXOS_DIR#default" "install targets chosen root"
  assert_file_contains "$TMP_ROOT/action.log" "nixos-enter --root $INSTALL_ROOT --command passwd jarq" "set selected user's password"
)

# A failing evaluation must stop installation even if the caller handles failure.
if (
  INSTALL_ACTION=install
  as_root() {
    if [ "$1" = nix ] && [ "$4" = eval ]; then return 1; fi
    if [ "$1" = nix ]; then return 0; fi
    printf 'unexpected install\n' > "$TMP_ROOT/unexpected-install"
  }
  run_selected_action
) >/dev/null 2>&1; then
  fail "failed evaluation was accepted"
fi
[ ! -e "$TMP_ROOT/unexpected-install" ] || fail "installed after failed evaluation"

# Exercise the entire dry-run dialogue; a dry run must not invoke privileged tools.
printf '3\n2\n1\n2\ndrybox\n' | (
  setup_prompt_input() { PROMPT_INPUT=""; }
  can_prompt() { return 0; }
  as_root() { fail "privileged command during dry run: $*"; }
  main --rebuild --dry-run --nixos-dir "$desktop_dir"
) > "$TMP_ROOT/main-dry-run.out"
assert_file_contains "$TMP_ROOT/main-dry-run.out" 'profile = "i3";' "full dialogue chooses i3"
assert_file_contains "$TMP_ROOT/main-dry-run.out" 'userName = "jarq";' "full dialogue chooses jarq"
assert_file_contains "$TMP_ROOT/main-dry-run.out" 'hostName = "drybox";' "full dialogue chooses hostname"
assert_file_contains "$TMP_ROOT/main-dry-run.out" '/nixos/hardware/kernel/lts.nix' "full dialogue chooses LTS"
assert_file_not_contains "$TMP_ROOT/main-dry-run.out" 'Disk setup:' "dry-run rebuild never offers disk setup"

# Guards stop automatic partitioning before any disk commands or prompts.
for mode in rebuild dry-run; do
  if (
    INSTALL_ACTION=install
    DRY_RUN=false
    if [ "$mode" = rebuild ]; then INSTALL_ACTION=rebuild; else DRY_RUN=true; fi
    detect_firmware() { fail "partition guard was bypassed"; }
    auto_partition
  ) > "$TMP_ROOT/guard-$mode.out" 2>&1; then
    fail "partitioning accepted in $mode"
  fi
done
assert_file_contains "$TMP_ROOT/guard-rebuild.out" 'partitioning is only available in install mode' "rebuild guard"
assert_file_contains "$TMP_ROOT/guard-dry-run.out" 'partitioning is unavailable during a dry run' "dry-run guard"

bash -n "$REPO_DIR/install.sh"

echo "PASS: install installer tests"
