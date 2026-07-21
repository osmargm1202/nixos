#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT/nixos/profiles/hyprland.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

if grep -Eq 'doCheck[[:space:]]*=[[:space:]]*false' "$PROFILE"; then
  fail 'Waybar checks must remain enabled'
fi

grep -Fq -- '--replace-fail "alarm(5);" "alarm(30);"' "$PROFILE" ||
  fail 'Waybar stress subprocess must retain a load-safe timeout'
grep -Fq -- '--replace-fail "for (int i = 0; i < 200; ++i)" "for (int i = 0; i < 20; ++i)"' "$PROFILE" ||
  fail 'Waybar packaging must bound the upstream thread stress repetition under parallel Nix builds'

printf 'PASS: Waybar checks remain enabled with bounded stress repetition\n'
