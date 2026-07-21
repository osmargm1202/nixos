#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HERDR_DOTFILES="$ROOT/dotfiles/config/shared/.config/herdr"
DOTFILES_MODULE="$ROOT/nixos/common-dotfiles.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[ ! -e "$HERDR_DOTFILES" ] ||
  fail 'Herdr runtime directory must not exist inside dotfiles'

if grep -Fq '.config/herdr' "$DOTFILES_MODULE"; then
  fail 'Nix/Home Manager must not link or own the Herdr runtime directory'
fi

printf 'PASS: Herdr configuration and state are exclusively runtime-owned\n'
