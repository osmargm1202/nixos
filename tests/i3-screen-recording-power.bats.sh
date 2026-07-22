#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT/nixos/profiles/i3.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

grep -Eq '^[[:space:]]+ffcast[[:space:]]*$' "$PROFILE" ||
  fail 'ffcast X11 screen-region recorder missing'
upower_block="$(awk '
  /^  services\.upower = \{/ { active = 1 }
  active { print }
  active && /^  \};/ { exit }
' "$PROFILE")"
[[ -n "$upower_block" ]] || fail 'UPower service block missing'
grep -Fq 'enable = true;' <<<"$upower_block" ||
  fail 'UPower service is not enabled'
grep -Fq 'package = pkgs.upower;' <<<"$upower_block" ||
  fail 'UPower CLI/package not pinned through its service'
grep -Fq 'services.power-profiles-daemon.enable = true;' "$PROFILE" ||
  fail 'power profile management daemon missing'

printf 'PASS: i3 includes ffcast recording, UPower telemetry and profile management\n'
