#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
I3="$ROOT/nixos/profiles/i3.nix"
DEV_SHELL="$ROOT/nixos/packages/dev-shell.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

deprecated='xorg\.(xorgserver|xinit|xauth|xrdb|xrandr|xinput|xset|xsetroot|setxkbmap|xkill)([^[:alnum:]_-]|$)'
if grep -RInE "$deprecated" "$ROOT/nixos"; then
  fail 'deprecated xorg package-set reference remains in Nix code'
fi

for package in xorg-server xinit xauth xrdb xrandr xinput xset xsetroot setxkbmap xkill; do
  grep -Eq "^[[:space:]]+${package}[[:space:]]*$" "$I3" ||
    fail "top-level Xorg package missing from i3: $package"
done

grep -Eq '^[[:space:]]+xauth[[:space:]]*$' "$DEV_SHELL" ||
  fail 'top-level xauth package missing from development shell'

printf 'PASS: Nix code uses top-level Xorg package names\n'
