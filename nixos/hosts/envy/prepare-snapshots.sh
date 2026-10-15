#!/usr/bin/env bash
set -euo pipefail

die() {
  printf 'Snapshot preparation refused: %s\n' "$*" >&2
  exit 1
}

[[ $# == 2 ]] || die 'expected two absolute mountpoints (root and home)'
[[ $1 == /* && $2 == /* && $1 != "$2" ]] || die 'expected distinct absolute mountpoints'

# Fail before any write if a runtime dependency or inventory command is absent.
for command in id findmnt btrfs chown chmod; do
  command -v "$command" >/dev/null || die "missing command: $command"
done
uid=$(id -u) || die 'cannot determine effective UID'
[[ $uid == 0 ]] || die 'must run as root'

mountpoints=("${1%/}" "${2%/}")
# Preserve the root slash while avoiding // in the snapshot paths.
for index in 0 1; do
  target=${mountpoints[$index]:-/}
  [[ ! -L $target ]] || die "symlink mountpoint: $target"
  # --mountpoint is intentional: --target would accept an unmounted /home
  # merely because its parent / is on Btrfs. Check status as well as stdout.
  filesystem=$(findmnt --noheadings --output FSTYPE --mountpoint "$target") || die "cannot inventory exact mountpoint: $target"
  [[ $filesystem == btrfs ]] || die "not an exact Btrfs mountpoint: $target"
done

# Validate BOTH mounts and ALL existing paths before making any changes. Never
# replace an ordinary directory/file, follow a symlink or delete existing data.
for target in "${mountpoints[@]}"; do
  snapshots=$target/.snapshots
  [[ ! -L $snapshots ]] || die "symlink snapshot path: $snapshots"
  if [[ -e $snapshots ]]; then
    [[ -d $snapshots ]] || die "not a directory: $snapshots"
    btrfs subvolume show -- "$snapshots" >/dev/null || die "not a verified subvolume: $snapshots"
  fi
done

umask 077
for target in "${mountpoints[@]}"; do
  snapshots=$target/.snapshots
  if [[ ! -e $snapshots ]]; then
    btrfs subvolume create -- "$snapshots"
  fi
  chown root:root -- "$snapshots"
  chmod 0700 -- "$snapshots"
done
