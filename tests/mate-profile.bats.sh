#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MATE_OUTPUT="orgm-mate"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

# Evaluate the mate output as a full derivation path (this previously failed
# because mate.extraPackages now throws).
[[ "$(nix eval --raw ".#nixosConfigurations.${MATE_OUTPUT}.config.system.build.toplevel.drvPath")" ]] || fail "could not evaluate ${MATE_OUTPUT}.config.system.build.toplevel.drvPath"

packages="$(nix eval --json ".#nixosConfigurations.${MATE_OUTPUT}.config.environment.systemPackages")"

jq -e 'any(.[]; test("mate-icon-theme-faenza"))' <<<"$packages" \
  || fail "${MATE_OUTPUT} no longer installs mate-icon-theme-faenza"
jq -e 'any(.[]; test("mate-utils"))' <<<"$packages" \
  || fail "${MATE_OUTPUT} no longer installs mate-utils"

echo "PASS: mate profile configuration evaluates and retains explicit mate packages"
