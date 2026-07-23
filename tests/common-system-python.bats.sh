#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMON="$ROOT/nixos/common.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

python_line="$(grep -nE '^    python3$' "$COMMON" | cut -d: -f1 || true)"
[ -n "$python_line" ] || fail 'common system packages must include python3'

uv_line="$(grep -nE '^    uv$' "$COMMON" | cut -d: -f1 || true)"
[ -n "$uv_line" ] || fail 'common system packages must include uv'
[ "$python_line" -eq $((uv_line + 1)) ] ||
  fail 'python3 must be adjacent to uv in common system packages'

printf 'PASS: common system packages include Python 3\n'
