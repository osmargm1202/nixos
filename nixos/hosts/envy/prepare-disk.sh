#!/usr/bin/env bash
# Intentionally host-specific: no arbitrary disk parameter is accepted.
set -euo pipefail
readonly disk_id=/dev/disk/by-id/nvme-INTEL_HBRPEKNX0202AH_PHTE9395032P512B-1
readonly expected_serial=PHTE9395032P512B-1
readonly expected_bytes=512110190592
mode=check
confirmation=
fail() { printf 'REFUSED: %s\n' "$*" >&2; exit 1; }
while (($#)); do
  case "$1" in
    --check) mode=check; shift ;;
    --format) mode=format; shift ;;
    --confirm)
      (($# >= 2)) || fail '--confirm requires the exact SSD serial'
      confirmation=$2; shift 2 ;;
    *) fail "Unknown argument: $1" ;;
  esac
done
for tool in readlink lsblk blockdev; do
  command -v "$tool" >/dev/null || fail "Missing tool: $tool"
done
disk=$(readlink -e "$disk_id") || fail 'Authorized SSD by-id does not exist'
[[ "$disk" == /dev/nvme0n1 ]] || fail 'SSD device mapping changed; re-inventory before erasing'
# Assign before comparing: [[ $(command) == expected ]] can hide a failed
# inventory command when its stdout still looks correct.
disk_type=$(lsblk -dnro TYPE "$disk") || fail 'Unable to inventory SSD type'
[[ "$disk_type" == disk ]] || fail 'Target must be a whole disk'
serial=$(lsblk -dnro SERIAL "$disk") || fail 'Unable to inventory SSD serial'
[[ "$serial" == "$expected_serial" ]] || fail 'SSD serial mismatch'
bytes=$(blockdev --getsize64 "$disk") || fail 'Unable to inventory SSD size'
[[ "$bytes" == "$expected_bytes" ]] || fail 'SSD size mismatch'
# Includes all descendant partitions. Any mounted target makes format unsafe.
mounts=$(lsblk -nr -o MOUNTPOINTS "$disk") || fail 'Unable to inventory SSD mounts'
[[ -z "${mounts//[[:space:]]/}" ]] || fail "Target or a descendant is mounted: $mounts"
printf 'Verified SSD: %s (%s, %s bytes)\n' "$disk" "$expected_serial" "$expected_bytes"
if [[ "$mode" == check ]]; then
  printf '%s\n' 'CHECK ONLY: no writes. Optane and installer USB are excluded.'
  exit 0
fi
[[ "$confirmation" == "$expected_serial" ]] || fail 'Destructive format requires --confirm PHTE9395032P512B-1'
uid=$(id -u) || fail 'Unable to determine effective UID'
[[ "$uid" == 0 ]] || fail 'Formatting requires root'
for tool in wipefs parted mkfs.fat mkfs.btrfs btrfs mount umount chattr mkdir udevadm; do
  command -v "$tool" >/dev/null || fail "Missing tool: $tool"
done
printf '%s\n' 'ERASING ONLY THE VERIFIED PRIMARY SSD; Optane and USB untouched.'
wipefs --all "$disk"
parted -s "$disk" -- mklabel gpt
parted -s "$disk" -- mkpart ENVY_EFI fat32 1MiB 1025MiB
parted -s "$disk" -- set 1 esp on
parted -s "$disk" -- mkpart ENVY_ROOT btrfs 1025MiB 100%
udevadm settle
mkfs.fat -F 32 -n ENVY_EFI "${disk}p1"
mkfs.btrfs -f -L ENVY_ROOT "${disk}p2"
mkdir -p /mnt
mount -t btrfs "${disk}p2" /mnt
for subvolume in @root @home @nix @log @windows; do
  btrfs subvolume create "/mnt/$subvolume"
done
# Set before any guest images exist; NOCOW cannot retrofit existing extents.
chattr +C /mnt/@windows
umount /mnt
mount -t btrfs -o subvol=@root,compress=zstd:3,noatime "${disk}p2" /mnt
mkdir -p /mnt/home /mnt/nix /mnt/var/log /mnt/var/lib/windows /mnt/boot
mount -t btrfs -o subvol=@home,compress=zstd:3,noatime "${disk}p2" /mnt/home
mount -t btrfs -o subvol=@nix,compress=zstd:3,noatime "${disk}p2" /mnt/nix
mount -t btrfs -o subvol=@log,compress=zstd:3,noatime "${disk}p2" /mnt/var/log
mount -t btrfs -o subvol=@windows,noatime "${disk}p2" /mnt/var/lib/windows
mount -t vfat -o fmask=0077,dmask=0077 "${disk}p1" /mnt/boot
printf '%s\n' 'Prepared /mnt. Install only the reviewed envy normal configuration.'
