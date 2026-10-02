#!/usr/bin/env bash
# ORGMOS Installer
# curl -fsSL https://raw.githubusercontent.com/osmargm1202/nixos/master/install.sh | bash
set -euo pipefail

REPO_URL="${ORGMOS_REPO_URL:-github:osmargm1202/nixos/master}"
NIXOS_DIR="${ORGMOS_NIXOS_DIR:-/etc/nixos}"
NIXOS_DIR_EXPLICIT=false
if [ -n "${ORGMOS_NIXOS_DIR+x}" ]; then
  NIXOS_DIR_EXPLICIT=true
fi
NIXOS_DIR_CANDIDATES="${ORGMOS_NIXOS_DIR_CANDIDATES:-/etc/nixos:/mnt/etc/nixos}"
INSTALL_ACTION="rebuild"
REQUESTED_ACTION="auto"
INSTALL_ROOT="/mnt"
BOOT_DISK=""
INSTALL_BOOT_MODULE=""
DRY_RUN=false
PROMPT_INPUT=""
FLAKE_PATH="$NIXOS_DIR/flake.nix"
HARDWARE_PATH="$NIXOS_DIR/hardware-configuration.nix"

profiles=(hyprland labwc i3 cinnamon gnome ryoku server terminal)
users=(osmarg jarq)
SELECTED_USER="osmarg"
gpus=(intel radeon nvidia)
kernels=(zen lts)

say() { printf '%s\n' "$*"; }
fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<EOF
Usage: install.sh [options]

Options:
  --dry-run             Print generated flake only; do not write or rebuild.
  --install             Install from a NixOS ISO into the target root.
  --rebuild             Configure an existing NixOS; never offer partitioning.
  --root PATH           Installation mountpoint (default /mnt); implies --install.
  --repo-url URL        Override ORGMOS flake input URL.
  --nixos-dir PATH      Override NixOS config directory.
  -h, --help            Show this help.

Examples:
  curl -fL https://nixos.or-gm.com/install -o /tmp/orgm-install.sh
  bash /tmp/orgm-install.sh --install
  bash /tmp/orgm-install.sh --rebuild --dry-run
EOF
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --dry-run) DRY_RUN=true; shift ;;
      --install) REQUESTED_ACTION="install"; shift ;;
      --rebuild) REQUESTED_ACTION="rebuild"; shift ;;
      --root) [ "$#" -ge 2 ] || fail "--root requires a value"; INSTALL_ROOT="${2%/}"; REQUESTED_ACTION="install"; shift 2 ;;
      --repo-url) [ "$#" -ge 2 ] || fail "--repo-url requires a value"; REPO_URL="$2"; shift 2 ;;
      --nixos-dir) [ "$#" -ge 2 ] || fail "--nixos-dir requires a value"; NIXOS_DIR="$2"; NIXOS_DIR_EXPLICIT=true; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) fail "unknown option: $1" ;;
    esac
  done
  [[ "$INSTALL_ROOT" = /* ]] || fail "--root must be an absolute path other than /"
  INSTALL_ROOT="$(readlink -m "$INSTALL_ROOT")"
  [ "$INSTALL_ROOT" != / ] || fail "--root must be an absolute path other than /"
  if [ "$REQUESTED_ACTION" = install ] && [ "$NIXOS_DIR_EXPLICIT" = false ]; then
    NIXOS_DIR="$INSTALL_ROOT/etc/nixos"
    NIXOS_DIR_EXPLICIT=true
  fi
  refresh_nixos_paths
}

setup_prompt_input() {
  PROMPT_INPUT=""
  if [ ! -t 0 ] && [ -e /dev/tty ] && { : < /dev/tty; } 2>/dev/null; then
    PROMPT_INPUT="/dev/tty"
  fi
}

read_prompt() {
  local prompt="$1" var_name="$2"
  if [ -n "$PROMPT_INPUT" ]; then
    read -r -p "$prompt" "$var_name" < "$PROMPT_INPUT"
  else
    read -r -p "$prompt" "$var_name"
  fi
}

confirm() {
  local prompt="$1" answer=""
  read_prompt "$prompt [y/N]: " answer
  case "$answer" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

is_base_profile() {
  [ "${SELECTED_PROFILE:-}" = "server" ] || [ "${SELECTED_PROFILE:-}" = "terminal" ]
}

refresh_nixos_paths() {
  FLAKE_PATH="$NIXOS_DIR/flake.nix"
  HARDWARE_PATH="$NIXOS_DIR/hardware-configuration.nix"
  INSTALL_ACTION="rebuild"
  case "$NIXOS_DIR" in /mnt|/mnt/*|*/mnt/etc/nixos) INSTALL_ACTION="install" ;; esac
  [ "$REQUESTED_ACTION" = auto ] || INSTALL_ACTION="$REQUESTED_ACTION"
}

final_command() {
  case "$INSTALL_ACTION" in
    install) printf 'sudo nixos-install --root %q --flake %q' "$INSTALL_ROOT" "path:$NIXOS_DIR#default" ;;
    *)       printf 'sudo nixos-rebuild switch --flake %q' "path:$NIXOS_DIR#default" ;;
  esac
}

can_prompt() { [ -t 0 ] || [ -n "$PROMPT_INPUT" ]; }

as_root() {
  if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo "$@"; fi
}

interactive_as_root() {
  if [ -n "$PROMPT_INPUT" ]; then
    as_root "$@" < "$PROMPT_INPUT"
  else
    as_root "$@"
  fi
}

choose_operation() {
  if [ "$REQUESTED_ACTION" = auto ]; then
    local choice="" default=2
    # The installed machine can also have /mnt mounted. Require a live-medium
    # marker before making disk installation the default.
    if [ -d /iso ] || grep -qE '^VARIANT_ID="?installer"?$' /etc/os-release; then
      default=1
    fi
    say "1) Install into $INSTALL_ROOT from a NixOS ISO"
    say "2) Configure the running NixOS (no partitioning)"
    read_prompt "Operation [1/2] default $default: " choice
    case "${choice:-$default}" in
      1) REQUESTED_ACTION=install ;;
      2) REQUESTED_ACTION=rebuild ;;
      *) fail "Invalid operation" ;;
    esac
  fi
  if [ "$REQUESTED_ACTION" = install ] && [ "$NIXOS_DIR_EXPLICIT" = false ]; then
    NIXOS_DIR="$INSTALL_ROOT/etc/nixos"
    NIXOS_DIR_EXPLICIT=true
  fi
  refresh_nixos_paths
  if [ "$INSTALL_ACTION" = install ]; then
    [ "$NIXOS_DIR" = "$INSTALL_ROOT/etc/nixos" ] || fail "installation config must be in $INSTALL_ROOT/etc/nixos (use --root)"
  fi
}

validate_disk() {
  local disk="$1" mounts=""
  [ -b "$disk" ] || fail "Not a block device: $disk"
  [ "$(lsblk -dnro TYPE "$disk")" = disk ] || fail "Select a whole disk, not a partition: $disk"
  mounts="$(lsblk -nro MOUNTPOINTS "$disk")"
  [[ ! "$mounts" =~ [^[:space:]] ]] || fail "Disk has mounted filesystems or active swap: $disk"
}

# ── disk auto-partition ───────────────────────────────────────────────────────

detect_firmware() {
  if [ -d /sys/firmware/efi ]; then
    FIRMWARE="uefi"
  else
    FIRMWARE="bios"
  fi
  say "Firmware detected: ${FIRMWARE}"
}

auto_partition() {
  [ "$INSTALL_ACTION" = install ] || fail "partitioning is only available in install mode"
  [ "$DRY_RUN" = false ] || fail "partitioning is unavailable during a dry run"
  mountpoint -q "$INSTALL_ROOT" && fail "Unmount $INSTALL_ROOT before automatic partitioning"
  detect_firmware

  say ""
  say "Available disks:"
  lsblk -d -o NAME,SIZE,MODEL | grep -v loop
  say ""
  local raw_disk="" disk="" answer="" tool
  read_prompt "Disk to partition (e.g. sda, vda, nvme0n1): " raw_disk
  disk="$(readlink -f "/dev/${raw_disk#/dev/}")"
  validate_disk "$disk"
  for tool in parted mkfs.ext4 mount nixos-generate-config udevadm; do
    command -v "$tool" >/dev/null || fail "Required command missing: $tool"
  done
  if [ "$FIRMWARE" = uefi ]; then
    command -v mkfs.fat >/dev/null || fail "Required command missing: mkfs.fat"
  fi
  say ""
  say "Layout: 1GiB boot + rest ext4 root, no encryption or swap (${FIRMWARE} mode)"
  say "WARNING: ALL DATA ON $disk WILL BE ERASED."
  read_prompt "Type $disk to confirm erasing this disk: " answer
  [ "$answer" = "$disk" ] || fail "Aborted: disk confirmation did not match"

  local part_boot part_root
  if [[ "$disk" =~ [0-9]$ ]]; then
    part_boot="${disk}p1"; part_root="${disk}p2"
  else
    part_boot="${disk}1";  part_root="${disk}2"
  fi

  if [ "$FIRMWARE" = "uefi" ]; then
    say "Partitioning ${disk} (GPT, UEFI)..."
    as_root parted -s "$disk" -- mklabel gpt
    as_root parted -s "$disk" -- mkpart ESP fat32 1MiB 1GiB
    as_root parted -s "$disk" -- set 1 esp on
    as_root parted -s "$disk" -- mkpart primary ext4 1GiB 100%
  else
    say "Partitioning ${disk} (MBR, BIOS)..."
    as_root parted -s "$disk" -- mklabel msdos
    as_root parted -s "$disk" -- mkpart primary ext4 1MiB 1GiB
    as_root parted -s "$disk" -- set 1 boot on
    as_root parted -s "$disk" -- mkpart primary ext4 1GiB 100%
  fi

  as_root udevadm settle
  [ -b "$part_boot" ] && [ -b "$part_root" ] || fail "Partition devices are not available"
  say "Formatting..."
  if [ "$FIRMWARE" = uefi ]; then
    as_root mkfs.fat -F 32 -n BOOT "$part_boot"
  else
    as_root mkfs.ext4 -L boot "$part_boot"
  fi
  as_root mkfs.ext4 -L nixos "$part_root"
  BOOT_DISK="$disk"

  say "Mounting to $INSTALL_ROOT..."
  as_root mkdir -p "$INSTALL_ROOT"
  as_root mount "$part_root" "$INSTALL_ROOT"
  as_root mkdir -p "$INSTALL_ROOT/boot"
  as_root mount "$part_boot" "$INSTALL_ROOT/boot"

  NIXOS_DIR="$INSTALL_ROOT/etc/nixos"
  as_root mkdir -p "$NIXOS_DIR"
  refresh_nixos_paths

  say "Generating hardware config..."
  as_root nixos-generate-config --root "$INSTALL_ROOT"
  say "Disk ready."
}

maybe_auto_partition() {
  if [ "$INSTALL_ACTION" = install ] && ! mountpoint -q "$INSTALL_ROOT"; then
    say ""
    say "Disk setup:"
    say "  1) Erase and partition a disk (1GiB boot + ext4 root, no encryption or swap)"
    say "  2) Use partitions mounted manually at $INSTALL_ROOT"
    say ""
    local choice=""
    read_prompt "Choice [1/2] default 2: " choice
    choice="${choice:-2}"
    case "$choice" in
      1) auto_partition ;;
      2) say "Skipping partition." ;;
      *) fail "Invalid choice" ;;
    esac
  fi
}

prepare_installation() {
  [ "$INSTALL_ACTION" = install ] || return 0
  mountpoint -q "$INSTALL_ROOT" || fail "Mount the target root at $INSTALL_ROOT first"
  mountpoint -q "$INSTALL_ROOT/boot" || fail "Mount the target boot partition at $INSTALL_ROOT/boot first"
  [ "$(findmnt -nro MAJ:MIN --mountpoint "$INSTALL_ROOT")" != "$(findmnt -nro MAJ:MIN --mountpoint /)" ] ||
    fail "Target root must be a different filesystem from the running NixOS"
  if [ -d /sys/firmware/efi ]; then
    [ "$(findmnt -nro FSTYPE --mountpoint "$INSTALL_ROOT/boot")" = vfat ] || fail "UEFI boot requires a FAT EFI system partition at $INSTALL_ROOT/boot"
  fi
  if [ ! -f "$HARDWARE_PATH" ]; then
    as_root nixos-generate-config --root "$INSTALL_ROOT"
  fi
}

configure_bootloader() {
  INSTALL_BOOT_MODULE=""
  [ "$INSTALL_ACTION" = install ] || return 0
  detect_firmware
  if [ "$FIRMWARE" = uefi ]; then
    INSTALL_BOOT_MODULE='boot.loader.systemd-boot.enable = lib.mkForce true;
        boot.loader.grub.enable = lib.mkForce false;
        boot.loader.efi.canTouchEfiVariables = lib.mkForce true;'
  else
    if [ -z "$BOOT_DISK" ]; then
      read_prompt "Whole disk for GRUB (e.g. /dev/sda): " BOOT_DISK
    fi
    [[ "$BOOT_DISK" =~ ^/dev/[a-zA-Z0-9/_-]+$ ]] || fail "Invalid GRUB disk path"
    if [ "$DRY_RUN" = false ]; then
      [ -b "$BOOT_DISK" ] && [ "$(lsblk -dnro TYPE "$BOOT_DISK")" = disk ] || fail "GRUB requires a whole disk"
    fi
    INSTALL_BOOT_MODULE="boot.loader.systemd-boot.enable = lib.mkForce false;
        boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
        boot.loader.grub.enable = lib.mkForce true;
        boot.loader.grub.efiSupport = lib.mkForce false;
        boot.loader.grub.devices = lib.mkForce [ \"$BOOT_DISK\" ];"
  fi
}

# ── nixos dir resolution ──────────────────────────────────────────────────────

prompt_nixos_dir() {
  local value=""
  while true; do
    read_prompt "NixOS config dir containing hardware-configuration.nix: " value
    value="${value%/}"
    if [ -f "$value/hardware-configuration.nix" ]; then
      NIXOS_DIR="$value"; refresh_nixos_paths; return 0
    fi
    say "Missing $value/hardware-configuration.nix."
  done
}

resolve_nixos_dir() {
  if [ "$NIXOS_DIR_EXPLICIT" = true ]; then
    NIXOS_DIR="${NIXOS_DIR%/}"; refresh_nixos_paths
    [ -f "$HARDWARE_PATH" ] && return 0
    can_prompt && { say "Missing $HARDWARE_PATH."; prompt_nixos_dir; return 0; }
    fail "missing $HARDWARE_PATH"
  fi

  local old_ifs="$IFS" checked="" candidate=""
  IFS=:
  for candidate in $NIXOS_DIR_CANDIDATES; do
    candidate="${candidate%/}"; [ -n "$candidate" ] || continue
    checked="${checked}${checked:+, }$candidate/hardware-configuration.nix"
    if [ -f "$candidate/hardware-configuration.nix" ]; then
      NIXOS_DIR="$candidate"; refresh_nixos_paths; IFS="$old_ifs"; return 0
    fi
  done
  IFS="$old_ifs"

  can_prompt && { say "No hardware-configuration.nix found in default locations."; prompt_nixos_dir; return 0; }
  fail "missing hardware-configuration.nix; checked: $checked"
}

require_nixos() {
  [ -e /etc/NIXOS ] || fail "this installer must run on NixOS"
  [ "$(uname -m)" = x86_64 ] || fail "this repository currently supports x86_64 only"
  command -v nix >/dev/null || fail "nix not found"
  case "$INSTALL_ACTION" in
    install)
      command -v nixos-install >/dev/null 2>&1 || fail "nixos-install not found"
      command -v nixos-enter >/dev/null 2>&1 || fail "nixos-enter not found"
      command -v nixos-generate-config >/dev/null 2>&1 || fail "nixos-generate-config not found"
      ;;
    *)       command -v nixos-rebuild  >/dev/null 2>&1 || fail "nixos-rebuild not found" ;;
  esac
}

# ── selections ────────────────────────────────────────────────────────────────

choose_profile() {
  say ""
  say "Choose ORGMOS profile:"
  local i
  for i in "${!profiles[@]}"; do
    say "  $((i + 1))) ${profiles[$i]}"
  done
  say ""
  local choice=""
  while true; do
    read_prompt "Profile [1-${#profiles[@]}] default 1 (${profiles[0]}): " choice
    choice="${choice:-1}"
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#profiles[@]}" ]; then
      SELECTED_PROFILE="${profiles[$((choice - 1))]}"; return 0
    fi
    say "Invalid selection."
  done
}

choose_gpu() {
  say ""
  say "Choose GPU driver:"
  say "  1) intel   2) radeon   3) nvidia"
  say ""
  local choice=""
  while true; do
    read_prompt "GPU [1-${#gpus[@]}] default 1 (${gpus[0]}): " choice
    choice="${choice:-1}"
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#gpus[@]}" ]; then
      SELECTED_GPU="${gpus[$((choice - 1))]}"
      case "$SELECTED_GPU" in
        intel)  SELECTED_GPU_MODULE='(orgmos.outPath + "/nixos/hardware/gpu/intel.nix")' ;;
        radeon) SELECTED_GPU_MODULE='(orgmos.outPath + "/nixos/hardware/gpu/radeon.nix")' ;;
        nvidia) SELECTED_GPU_MODULE='(orgmos.outPath + "/nixos/hardware/gpu/nvidia.nix")' ;;
      esac
      return 0
    fi
    say "Invalid selection."
  done
}

choose_kernel() {
  say ""
  say "Choose kernel:"
  say "  1) zen   2) lts"
  say ""
  local choice=""
  while true; do
    read_prompt "Kernel [1-${#kernels[@]}] default 1 (${kernels[0]}): " choice
    choice="${choice:-1}"
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#kernels[@]}" ]; then
      SELECTED_KERNEL="${kernels[$((choice - 1))]}"
      case "$SELECTED_KERNEL" in
        zen) SELECTED_KERNEL_MODULE='(orgmos.outPath + "/nixos/hardware/kernel/zen.nix")' ;;
        lts) SELECTED_KERNEL_MODULE='(orgmos.outPath + "/nixos/hardware/kernel/lts.nix")' ;;
      esac
      return 0
    fi
    say "Invalid selection."
  done
}

choose_user() {
  say ""
  say "Choose a user configuration (applications and dotfiles):"
  local i available_users=("${users[@]}")
  if [ "$SELECTED_PROFILE" = ryoku ]; then
    available_users=(osmarg)
    say "Ryoku currently supports osmarg's personal configuration only."
  fi
  for i in "${!available_users[@]}"; do
    say "  $((i + 1))) ${available_users[$i]}"
  done
  say ""
  local choice=""
  while true; do
    read_prompt "User [1-${#available_users[@]}] default 1 (${available_users[0]}): " choice
    choice="${choice:-1}"
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#available_users[@]}" ]; then
      SELECTED_USER="${available_users[$((choice - 1))]}"
      return 0
    fi
    say "Invalid selection."
  done
}

choose_hostname() {
  say ""
  local current
  current="$(hostname 2>/dev/null || printf orgmos)"
  read_prompt "Hostname [${current}]: " SELECTED_HOSTNAME
  SELECTED_HOSTNAME="${SELECTED_HOSTNAME:-$current}"
  [[ "$SELECTED_HOSTNAME" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$ ]] &&
    [ "${#SELECTED_HOSTNAME}" -le 63 ] || fail "hostname must be 1-63 letters, numbers or internal hyphens"
}

# ── flake generation ──────────────────────────────────────────────────────────

nixos_dir_command() {
  if [ -w "$NIXOS_DIR" ]; then "$@"; else as_root "$@"; fi
}

backup_existing_flake() {
  local file backup timestamp
  timestamp="$(date +%Y%m%d-%H%M%S-%N)"
  for file in "$FLAKE_PATH" "$NIXOS_DIR/flake.lock"; do
    if [ -e "$file" ]; then
      backup="$file.backup.$timestamp"
      say "Backing up existing configuration: $backup"
      nixos_dir_command cp "$file" "$backup"
    fi
  done
}

write_flake() {
  local tmp helper profile_argument="" selected_modules="" profile_settings="" nh_path="$NIXOS_DIR"
  tmp="$(mktemp)"
  case "$SELECTED_PROFILE" in
    server) helper=mkServerHost ;;
    terminal) helper=mkTerminalHost ;;
    *)
      helper=mkGeneralHost
      profile_argument="profile = \"$SELECTED_PROFILE\";"
      selected_modules="$SELECTED_GPU_MODULE
        $SELECTED_KERNEL_MODULE"
      ;;
  esac
  [ "$INSTALL_ACTION" != install ] || nh_path=/etc/nixos
  # Escape strings without allowing Nix interpolation in user-supplied paths.
  local repo_nix nh_nix update_flake_nix
  repo_nix="$(nix_string "$REPO_URL")"
  nh_nix="$(nix_string "path:$nh_path#default")"
  if [ "$SELECTED_PROFILE" = ryoku ]; then
    update_flake_nix="$(nix_string "path:$nh_path")"
    profile_settings="programs.ryoku.updateFlake = lib.mkForce $update_flake_nix;
          programs.ryoku.updateInput = lib.mkForce \"orgmos\";"
  fi
  cat > "$tmp" <<EOF
{
  inputs.orgmos.url = $repo_nix;

  outputs = { self, orgmos, ... }: {
    nixosConfigurations.default = orgmos.lib.$helper {
      hardware = ./hardware-configuration.nix;
      $profile_argument
      hostName = "$SELECTED_HOSTNAME";
      userName = "$SELECTED_USER";
      extraModules = [
        $selected_modules
        ({ lib, ... }: {
          programs.nh.flake = lib.mkForce $nh_nix;
          $profile_settings
          $INSTALL_BOOT_MODULE
        })
      ];
    };
  };
}
EOF

  say ""; say "Generated flake:"; say "---"; cat "$tmp"; say "---"; say ""

  if [ "$DRY_RUN" = true ]; then
    say "Dry run: not writing $FLAKE_PATH."
    rm -f "$tmp"; return 0
  fi

  confirm "Write to $FLAKE_PATH?" || { rm -f "$tmp"; fail "aborted before writing flake"; }
  backup_existing_flake
  nixos_dir_command install -m 0644 "$tmp" "$FLAKE_PATH"
  rm -f "$tmp"
}

nix_string() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//\$\{/\\\$\{}"
  printf '"%s"' "$value"
}

run_selected_action() {
  # Reusing a previous lock could leave this installer on obsolete modules.
  as_root nix --extra-experimental-features 'nix-command flakes' flake update orgmos \
    --flake "path:$NIXOS_DIR" || fail "could not update the ORGMOS input; installation/rebuild was not started"
  # Fail on incompatible/unpublished repository modules before installing or
  # switching the system.
  as_root nix --extra-experimental-features 'nix-command flakes' eval --raw \
    "path:$NIXOS_DIR#nixosConfigurations.default.config.system.build.toplevel.drvPath" >/dev/null ||
    fail "configuration evaluation failed; installation/rebuild was not started"
  case "$INSTALL_ACTION" in
    install)
      interactive_as_root nixos-install --root "$INSTALL_ROOT" --flake "path:$NIXOS_DIR#default" || fail "nixos-install failed"
      say "Set the login password for $SELECTED_USER (separate from any disk encryption password)."
      interactive_as_root nixos-enter --root "$INSTALL_ROOT" --command "passwd $SELECTED_USER" ||
        fail "Could not set the user password; run nixos-enter --root $INSTALL_ROOT --command 'passwd $SELECTED_USER' before rebooting"
      say "Installation complete. Unmount the target and reboot when ready."
      ;;
    *) as_root nixos-rebuild switch --flake "path:$NIXOS_DIR#default" ;;
  esac
}

# ── main ──────────────────────────────────────────────────────────────────────

main() {
  parse_args "$@"
  setup_prompt_input
  can_prompt || fail "interactive terminal required; download the script and run bash install.sh"

  say "ORGMOS installer"
  say "================"

  choose_operation
  # Validate the platform and required installer before touching any disk.
  [ "$DRY_RUN" = true ] || require_nixos
  if [ "$DRY_RUN" = false ]; then
    maybe_auto_partition
    prepare_installation
  fi

  resolve_nixos_dir
  if [ "$INSTALL_ACTION" = install ]; then
    [ "$NIXOS_DIR" = "$INSTALL_ROOT/etc/nixos" ] || fail "installation config must be in $INSTALL_ROOT/etc/nixos"
  fi

  if [ "$DRY_RUN" = true ]; then
    say "Dry run: no target files will be written and no install command will run."
  fi

  configure_bootloader
  choose_profile
  choose_user
  if ! is_base_profile; then
    choose_gpu
    choose_kernel
  fi
  choose_hostname

  say ""
  say "Summary:"
  say "  Repository : $REPO_URL"
  say "  NixOS dir  : $NIXOS_DIR"
  say "  Mode       : $INSTALL_ACTION"
  say "  Profile    : $SELECTED_PROFILE"
  say "  User       : $SELECTED_USER"
  if [ "$INSTALL_ACTION" = install ]; then
    say "  Boot       : $FIRMWARE"
    say "  Encryption : retained if partitions were prepared with LUKS; automatic partitioning is unencrypted"
  fi
  if ! is_base_profile; then
    say "  GPU        : $SELECTED_GPU"
    say "  Kernel     : $SELECTED_KERNEL"
  fi
  say "  Hostname   : $SELECTED_HOSTNAME"
  say ""

  write_flake

  if [ "$DRY_RUN" = true ]; then
    say "Dry run complete. Next command would be:"; say "  $(final_command)"; return 0
  fi

  say "Next command: $(final_command)"
  if confirm "Run now?"; then
    run_selected_action
  else
    say "Run manually when ready:"; say "  $(final_command)"
  fi
}

if [ "${ORGMOS_INSTALLER_TEST:-}" != "1" ]; then
  main "$@"
fi
