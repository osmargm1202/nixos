#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="$ROOT/nixos/hosts/lenovo/p14s-gen2i.nix"
LTS="$ROOT/nixos/hardware/kernel/lts.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

grep -Fq '../../hardware/kernel/lts.nix' "$HOST" ||
  fail 'Lenovo P14s must import the LTS kernel module'

if grep -Fq '../../hardware/kernel/zen70-pin.nix' "$HOST"; then
  fail 'Lenovo P14s must not import the Zen 7.0 pin'
fi

grep -Fq 'boot.kernelPackages = pkgs.linuxPackages_6_12;' "$LTS" ||
  fail 'LTS module must select linuxPackages_6_12'

printf 'PASS: all Lenovo graphical profiles select Linux LTS\n'
