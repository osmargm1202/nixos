#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLAKE="$REPO_DIR/flake.nix"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local pattern="$1" name="$2"
  grep -Eq -- "$pattern" "$FLAKE" || fail "$name"
}

assert_not_contains() {
  local pattern="$1" name="$2"
  if grep -Eq -- "$pattern" "$FLAKE"; then
    fail "$name"
  fi
}

assert_not_contains '^[[:space:]]*jarq[[:space:]]*=[[:space:]]*mkHost' "plain jarq output must not exist; use jarq-gnome or jarq-cinnamon"
assert_contains '^[[:space:]]*jarq-gnome[[:space:]]*=[[:space:]]*mkHost' "jarq-gnome output must exist"
assert_contains '^[[:space:]]*jarq-cinnamon[[:space:]]*=[[:space:]]*mkHost' "jarq-cinnamon output must exist"

awk '
  /^[[:space:]]*jarq-gnome[[:space:]]*=[[:space:]]*mkHost/ { in_block = 1 }
  in_block && /profile = \.\/nixos\/profiles\/gnome\.nix;/ { found = 1 }
  in_block && /^[[:space:]]*};/ { in_block = 0 }
  END { exit found ? 0 : 1 }
' "$FLAKE" || fail "jarq-gnome must use gnome profile"

awk '
  /^[[:space:]]*jarq-cinnamon[[:space:]]*=[[:space:]]*mkHost/ { in_block = 1 }
  in_block && /profile = \.\/nixos\/profiles\/cinnamon\.nix;/ { found = 1 }
  in_block && /^[[:space:]]*};/ { in_block = 0 }
  END { exit found ? 0 : 1 }
' "$FLAKE" || fail "jarq-cinnamon must use cinnamon profile"

echo "PASS: flake output tests"
