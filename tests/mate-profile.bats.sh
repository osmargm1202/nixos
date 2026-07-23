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

# Convert to package name list (drop version suffix from derivation names)
package_names="$(printf '%s\n' "$packages" | jq -r '.[] | split("/")[-1] | sub("^[0-9a-z]{32}-"; "") | sub("-[0-9][0-9a-zA-Z._+~:-]*$"; "")' )"

required=(
  mate-applets
  mate-icon-theme-faenza
  atril
  caja-extensions
  caja-with-extensions
  eom
  engrampa
  mate-backgrounds
  mate-calc
  mate-indicator-applet
  mate-media
  mate-netbook
  mate-power-manager
  mate-screensaver
  mate-system-monitor
  mate-terminal
  mate-user-guide
  mate-utils
  mozo
  pluma
)

for pkg in "${required[@]}"; do
  grep -Fxq "$pkg" <<<"$package_names" || fail "${MATE_OUTPUT} missing expected package ${pkg}"
done

for excluded in mate-user-share caja; do
  if grep -Fxq "$excluded" <<<"$package_names"; then
    fail "${MATE_OUTPUT} unexpectedly includes ${excluded}"
  fi
done

echo "PASS: mate profile configuration retains exact migrated package set"
