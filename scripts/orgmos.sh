#!/usr/bin/env bash
# ORGMOS Installer — curl https://nixos.or-gm.com/orgmos.sh | bash
# Partitions disk, clones flake, injects real hardware config, installs NixOS.
set -euo pipefail

FLAKE_REPO="https://github.com/osmargm1202/nixos.git"
FLAKE_BRANCH="master"
INSTALL_MNT="/mnt"
FLAKE_DIR="${INSTALL_MNT}/etc/nixos"
GENERIC_HW="${FLAKE_DIR}/nixos/hosts/generic/hardware-configuration.nix"

R='\033[0;31m' G='\033[0;32m' B='\033[0;34m' Y='\033[1;33m' N='\033[0m'
info()  { echo -e "${B}:: ${N}$*"; }
ok()    { echo -e "${G}ok  ${N}$*"; }
warn()  { echo -e "${Y}!   ${N}$*"; }
die()   { echo -e "${R}ERR ${N}$*" >&2; exit 1; }

require_root() { [ "$(id -u)" -eq 0 ] || die "Run as root (sudo bash orgmos.sh)"; }

# ── profile menu ──────────────────────────────────────────────────────────────
pick_profile() {
  echo ""
  echo -e "${B}ORGMOS Profile Selector${N}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Wayland compositors:"
  echo "    1) hyprland   — tiling Wayland WM"
  echo "    2) labwc      — stacking Wayland WM (lightweight)"
  echo "  X11 window managers:"
  echo "    3) i3         — tiling X11 WM"
  echo "  Desktop environments:"
  echo "    4) cinnamon   — Cinnamon DE"
  echo "    5) gnome      — GNOME DE"
  echo "    6) xfce       — XFCE DE"
  echo "    7) mate       — MATE DE"
  echo "  Base:"
  echo "    8) terminal   — no GUI, CLI only"
  echo "    9) server     — headless server"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  read -rp "Profile [1-9]: " choice
  case "$choice" in
    1) PROFILE="hyprland" ;;
    2) PROFILE="labwc" ;;
    3) PROFILE="i3" ;;
    4) PROFILE="cinnamon" ;;
    5) PROFILE="gnome" ;;
    6) PROFILE="xfce" ;;
    7) PROFILE="mate" ;;
    8) PROFILE="terminal" ;;
    9) PROFILE="server" ;;
    *) die "Invalid choice: $choice" ;;
  esac
  ok "Profile: ${PROFILE}"
}

# ── hostname ──────────────────────────────────────────────────────────────────
pick_hostname() {
  echo ""
  read -rp "Hostname [nixos]: " HOSTNAME
  HOSTNAME="${HOSTNAME:-nixos}"
  ok "Hostname: ${HOSTNAME}"
}

# ── disk setup ────────────────────────────────────────────────────────────────
pick_disk_mode() {
  echo ""
  echo -e "${B}Disk Setup${N}"
  echo "  1) Auto-partition a disk (UEFI, ext4, single disk)"
  echo "  2) Manual — /mnt already mounted by me"
  echo ""
  read -rp "Mode [1/2]: " mode
  case "$mode" in
    1) auto_partition ;;
    2) info "Skipping partition — using existing /mnt mount." ;;
    *) die "Invalid choice" ;;
  esac
}

auto_partition() {
  echo ""
  info "Available disks:"
  lsblk -d -o NAME,SIZE,MODEL | grep -v loop
  echo ""
  read -rp "Disk to partition (e.g. sda, vda, nvme0n1): " raw_disk
  DISK="/dev/${raw_disk}"
  [ -b "$DISK" ] || die "Not a block device: $DISK"
  echo ""
  warn "WILL ERASE ALL DATA ON $DISK — continue? [yes/N]"
  read -r confirm
  [ "$confirm" = "yes" ] || die "Aborted."

  info "Partitioning ${DISK}..."
  parted -s "$DISK" -- mklabel gpt
  parted -s "$DISK" -- mkpart ESP fat32 1MB 512MB
  parted -s "$DISK" -- set 1 esp on
  parted -s "$DISK" -- mkpart primary ext4 512MB 100%

  # resolve partition names (nvme uses p1/p2, others use 1/2)
  if echo "$DISK" | grep -q "nvme"; then
    PART_BOOT="${DISK}p1"
    PART_ROOT="${DISK}p2"
  else
    PART_BOOT="${DISK}1"
    PART_ROOT="${DISK}2"
  fi

  info "Formatting..."
  mkfs.fat -F 32 -n BOOT "$PART_BOOT"
  mkfs.ext4 -L nixos "$PART_ROOT"

  info "Mounting..."
  mount "$PART_ROOT" "$INSTALL_MNT"
  mkdir -p "${INSTALL_MNT}/boot"
  mount "$PART_BOOT" "${INSTALL_MNT}/boot"
  ok "Disk ready."
}

# ── hardware config ───────────────────────────────────────────────────────────
generate_hardware_config() {
  info "Generating hardware-configuration.nix..."
  nixos-generate-config --root "$INSTALL_MNT" --no-filesystems 2>/dev/null || \
    nixos-generate-config --root "$INSTALL_MNT"
  ok "Hardware config generated at ${INSTALL_MNT}/etc/nixos/hardware-configuration.nix"
}

# ── clone flake ───────────────────────────────────────────────────────────────
clone_flake() {
  info "Cloning ORGMOS flake..."
  mkdir -p "$(dirname "$FLAKE_DIR")"
  if [ -d "${FLAKE_DIR}/.git" ]; then
    warn "Flake dir exists — pulling latest..."
    git -C "$FLAKE_DIR" pull --ff-only origin "$FLAKE_BRANCH"
  else
    git clone --branch "$FLAKE_BRANCH" --depth 1 "$FLAKE_REPO" "$FLAKE_DIR"
  fi
  ok "Flake cloned to ${FLAKE_DIR}"
}

# ── inject hardware config ────────────────────────────────────────────────────
inject_hardware() {
  local generated="${INSTALL_MNT}/etc/nixos/hardware-configuration.nix"
  [ -f "$generated" ] || die "hardware-configuration.nix not found at $generated"
  info "Injecting hardware config into generic slot..."
  cp "$generated" "$GENERIC_HW"
  # also patch hostname in flake if needed
  ok "Hardware config injected."
}

# ── set hostname ──────────────────────────────────────────────────────────────
patch_hostname() {
  # Patch generic hardware config to also set hostname so mkProfile picks it up
  # Append only if not already present (idempotent)
  if ! grep -q "networking.hostName" "$GENERIC_HW"; then
    echo "" >> "$GENERIC_HW"
    echo "  # injected by orgmos.sh" >> "$GENERIC_HW"
    # Insert before closing brace
    sed -i "s/^}$/  networking.hostName = \"${HOSTNAME}\";\n}/" "$GENERIC_HW"
  fi
  ok "Hostname '${HOSTNAME}' set."
}

# ── install ───────────────────────────────────────────────────────────────────
run_install() {
  info "Installing NixOS with profile '${PROFILE}'..."
  info "This will take a while on first run (downloading packages)."
  echo ""

  # Enable flakes in the live env if needed
  mkdir -p /etc/nix
  grep -q "experimental-features" /etc/nix/nix.conf 2>/dev/null || \
    echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf

  nixos-install \
    --root "$INSTALL_MNT" \
    --flake "${FLAKE_DIR}#${PROFILE}" \
    --no-root-passwd \
    --option accept-flake-config true

  ok "Installation complete!"
}

# ── post-install summary ──────────────────────────────────────────────────────
summary() {
  echo ""
  echo -e "${G}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
  echo -e "${G}  ORGMOS installed successfully!${N}"
  echo -e "${G}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
  echo "  Profile  : ${PROFILE}"
  echo "  Hostname : ${HOSTNAME}"
  echo "  Flake    : ${FLAKE_DIR}"
  echo ""
  echo "  Next steps:"
  echo "    1. Set root password:  nixos-enter --root /mnt -- passwd"
  echo "    2. Set user password:  nixos-enter --root /mnt -- passwd osmarg"
  echo "    3. Reboot:             reboot"
  echo ""
}

# ── main ──────────────────────────────────────────────────────────────────────
main() {
  require_root
  echo ""
  echo -e "${B}╔══════════════════════════════════════╗${N}"
  echo -e "${B}║         ORGMOS NixOS Installer       ║${N}"
  echo -e "${B}╚══════════════════════════════════════╝${N}"
  echo ""

  pick_profile
  pick_hostname
  pick_disk_mode
  generate_hardware_config
  clone_flake
  inject_hardware
  patch_hostname
  run_install
  summary
}

main "$@"
