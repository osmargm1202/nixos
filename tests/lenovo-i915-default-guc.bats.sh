#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE="$ROOT/nixos/hosts/lenovo/p14s-gen2i-base.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

if grep -Fq 'i915.enable_guc' "$BASE"; then
  fail 'Lenovo P14s must use the kernel default GuC policy'
fi

grep -Fq '../../hardware/kernel/lts.nix' "$BASE" ||
  fail 'Lenovo P14s must remain on Linux LTS'

printf 'PASS: Lenovo P14s uses default i915 GuC policy\n'
