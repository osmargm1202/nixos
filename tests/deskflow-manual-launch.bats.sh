#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE="$ROOT/nixos/deskflow.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

grep -Fq '"org.deskflow.deskflow"' "$MODULE" ||
  fail 'Deskflow Flatpak must remain installed for manual launch'

for forbidden in \
  'systemd.user.services.deskflow' \
  'deskflowLauncher' \
  'writeShellScript' \
  'WantedBy' \
  'RestartSec' \
  'flatpak kill'; do
  if grep -Fq "$forbidden" "$MODULE"; then
    fail "Deskflow module still contains automatic service behavior: $forbidden"
  fi
done

printf 'PASS: Deskflow remains installed without automatic service startup\n'
