#!/usr/bin/env bash
# ORGMOS Installer
# curl -fsSL https://raw.githubusercontent.com/osmargm1202/nixos/master/install.sh | bash
set -euo pipefail

SCRIPT_URL="https://raw.githubusercontent.com/osmargm1202/nixos/master/install.sh"

# Re-exec as root — download to tmpfile so sudo has a real script path
if [ "$(id -u)" -ne 0 ]; then
  tmpf=$(mktemp /tmp/orgmos-install.XXXXXX.sh)
  trap 'rm -f "$tmpf"' EXIT
  printf 'Downloading installer to %s...\n' "$tmpf"
  curl -fsSL "$SCRIPT_URL" -o "$tmpf"
  chmod +x "$tmpf"
  printf 'Entering root shell (one password prompt)...\n'
  exec sudo bash "$tmpf" "$@"
fi

REPO_URL="${ORGMOS_REPO_URL:-github:osmargm1202/nixos}"
NIXOS_DIR="${ORGMOS_NIXOS_DIR:-/etc/nixos}"
NIXOS_DIR_EXPLICIT=false
if [ -n "${ORGMOS_NIXOS_DIR+x}" ]; then
  NIXOS_DIR_EXPLICIT=true
fi
NIXOS_DIR_CANDIDATES="${ORGMOS_NIXOS_DIR_CANDIDATES:-/etc/nixos:/mnt/etc/nixos}"
INSTALL_ACTION="rebuild"
DRY_RUN=false
PROMPT_INPUT=""
FLAKE_PATH="$NIXOS_DIR/flake.nix"
HARDWARE_PATH="$NIXOS_DIR/hardware-configuration.nix"

profiles=(hyprland labwc sway i3 cinnamon gnome xfce mate server terminal)
gpus=(intel radeon nvidia)
kernels=(zen lts)

say() { printf '%s\n' "$*"; }
fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<EOF
Usage: install.sh [options]

Options:
  --dry-run             Print generated flake only; do not write or rebuild.
  --repo-url URL        Override ORGMOS flake input URL.
  --nixos-dir PATH      Override NixOS config directory.
  -h, --help            Show this help.

Examples:
  curl -fsSL https://raw.githubusercontent.com/osmargm1202/nixos/master/install.sh | bash
  curl -fsSL https://raw.githubusercontent.com/osmargm1202/nixos/master/install.sh | bash -s -- --dry-run
EOF
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --dry-run) DRY_RUN=true; shift ;;
      --repo-url) [ "$#" -ge 2 ] || fail "--repo-url requires a value"; REPO_URL="$2"; shift 2 ;;
      --nixos-dir) [ "$#" -ge 2 ] || fail "--nixos-dir requires a value"; NIXOS_DIR="$2"; NIXOS_DIR_EXPLICIT=true; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) fail "unknown option: $1" ;;
    esac
  done
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
}

final_command() {
  case "$INSTALL_ACTION" in
    install) printf 'sudo nixos-install --flake %s#default' "$NIXOS_DIR" ;;
    *)       printf 'sudo nixos-rebuild switch --flake %s#default' "$NIXOS_DIR" ;;
  esac
}

can_prompt() { [ -t 0 ] || [ -n "$PROMPT_INPUT" ]; }

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
  detect_firmware

  say ""
  say "Available disks:"
  lsblk -d -o NAME,SIZE,MODEL | grep -v loop
  say ""
  read_prompt "Disk to partition (e.g. sda, vda, nvme0n1): " raw_disk
  local disk="/dev/${raw_disk}"
  [ -b "$disk" ] || fail "Not a block device: $disk"
  say ""
  say "Layout: 512MB boot + rest root, no swap (${FIRMWARE} mode)"
  say "WARNING: ALL DATA ON $disk WILL BE ERASED."
  confirm "Continue?" || fail "Aborted."

  local part_boot part_root
  if echo "$disk" | grep -q "nvme"; then
    part_boot="${disk}p1"; part_root="${disk}p2"
  else
    part_boot="${disk}1";  part_root="${disk}2"
  fi

  if [ "$FIRMWARE" = "uefi" ]; then
    say "Partitioning ${disk} (GPT, UEFI)..."
    parted -s "$disk" -- mklabel gpt
    parted -s "$disk" -- mkpart ESP fat32 1MB 512MB
    parted -s "$disk" -- set 1 esp on
    parted -s "$disk" -- mkpart primary ext4 512MB 100%

    say "Formatting..."
    mkfs.fat -F 32 -n BOOT "$part_boot"
    mkfs.ext4 -L nixos -F "$part_root"
  else
    say "Partitioning ${disk} (MBR, BIOS)..."
    parted -s "$disk" -- mklabel msdos
    parted -s "$disk" -- mkpart primary ext4 1MB 512MB
    parted -s "$disk" -- set 1 boot on
    parted -s "$disk" -- mkpart primary ext4 512MB 100%

    say "Formatting..."
    mkfs.ext4 -L boot -F "$part_boot"
    mkfs.ext4 -L nixos -F "$part_root"
  fi

  say "Mounting to /mnt..."
  mount "$part_root" /mnt
  mkdir -p /mnt/boot
  mount "$part_boot" /mnt/boot

  NIXOS_DIR="/mnt/etc/nixos"
  mkdir -p "$NIXOS_DIR"
  refresh_nixos_paths

  say "Generating hardware config..."
  nixos-generate-config --root /mnt
  say "Disk ready."
}

maybe_auto_partition() {
  # Only offer during fresh install (not rebuild) and when /mnt is not yet mounted
  if [ "$INSTALL_ACTION" = "install" ] || ! mountpoint -q /mnt 2>/dev/null; then
    say ""
    say "Disk setup:"
    say "  1) Auto-partition a disk (512MB boot + rest root, no swap)"
    say "  2) Skip — I already mounted /mnt"
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
  case "$INSTALL_ACTION" in
    install) command -v nixos-install >/dev/null 2>&1 || fail "nixos-install not found" ;;
    *)       command -v nixos-rebuild  >/dev/null 2>&1 || fail "nixos-rebuild not found" ;;
  esac
}

# ── selections ────────────────────────────────────────────────────────────────

choose_profile() {
  say ""
  say "Choose ORGMOS profile:"
  say "  Wayland WM:          1) hyprland   2) labwc   3) sway"
  say "  X11 WM:              4) i3"
  say "  Desktop environment: 5) cinnamon   6) gnome   7) xfce   8) mate"
  say "  Base:                9) server     10) terminal"
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
        intel)  SELECTED_GPU_MODULE='orgmos.nixosModules.gpu.intel' ;;
        radeon) SELECTED_GPU_MODULE='orgmos.nixosModules.gpu.radeon' ;;
        nvidia) SELECTED_GPU_MODULE='orgmos.nixosModules.gpu.nvidia' ;;
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
        zen) SELECTED_KERNEL_MODULE='orgmos.nixosModules.kernel.zen' ;;
        lts) SELECTED_KERNEL_MODULE='orgmos.nixosModules.kernel.lts' ;;
      esac
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
  [[ "$SELECTED_HOSTNAME" =~ ^[a-zA-Z0-9-]+$ ]] || fail "hostname may only contain letters, numbers, and hyphens"
}

# ── flake generation ──────────────────────────────────────────────────────────

nixos_dir_command() {
  [ -w "$NIXOS_DIR" ] && "$@" || sudo "$@"
}

backup_existing_flake() {
  if [ -e "$FLAKE_PATH" ]; then
    local backup="$FLAKE_PATH.backup.$(date +%Y%m%d-%H%M%S)"
    say "Backing up existing flake: $backup"
    nixos_dir_command cp "$FLAKE_PATH" "$backup"
  fi
}

write_flake() {
  local tmp
  tmp="$(mktemp)"

  case "$SELECTED_PROFILE" in
    server)
      cat > "$tmp" <<EOF
{
  inputs.orgmos.url = "$REPO_URL";

  outputs = { self, orgmos, ... }: {
    nixosConfigurations.default = orgmos.lib.mkServerHost {
      hardware = ./hardware-configuration.nix;
      hostName = "$SELECTED_HOSTNAME";
    };
  };
}
EOF
      ;;
    terminal)
      cat > "$tmp" <<EOF
{
  inputs.orgmos.url = "$REPO_URL";

  outputs = { self, orgmos, ... }: {
    nixosConfigurations.default = orgmos.lib.mkTerminalHost {
      hardware = ./hardware-configuration.nix;
      hostName = "$SELECTED_HOSTNAME";
    };
  };
}
EOF
      ;;
    *)
      cat > "$tmp" <<EOF
{
  inputs.orgmos.url = "$REPO_URL";

  outputs = { self, orgmos, ... }: {
    nixosConfigurations.default = orgmos.lib.mkGeneralHost {
      hardware = ./hardware-configuration.nix;
      profile = "$SELECTED_PROFILE";
      hostName = "$SELECTED_HOSTNAME";
      extraModules = [
        $SELECTED_GPU_MODULE
        $SELECTED_KERNEL_MODULE
      ];
    };
  };
}
EOF
      ;;
  esac

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

# ── main ──────────────────────────────────────────────────────────────────────

main() {
  parse_args "$@"
  setup_prompt_input

  say "ORGMOS installer"
  say "================"

  # offer disk partitioning only in fresh-install context
  if [ "$DRY_RUN" = false ]; then
    maybe_auto_partition
  fi

  resolve_nixos_dir

  [ "$DRY_RUN" = true ] && say "Dry run: no files will be written and no install command will run." || require_nixos

  choose_profile
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
    case "$INSTALL_ACTION" in
      install) sudo nixos-install --flake "$NIXOS_DIR#default" ;;
      *)       sudo nixos-rebuild switch --flake "$NIXOS_DIR#default" ;;
    esac
  else
    say "Run manually when ready:"; say "  $(final_command)"
  fi
}

if [ "${ORGMOS_INSTALLER_TEST:-}" != "1" ]; then
  main "$@"
fi
