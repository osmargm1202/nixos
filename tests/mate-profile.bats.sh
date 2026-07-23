#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MATE_OUTPUT="orgm-mate"
MATE_PROFILE="$REPO_DIR/nixos/profiles/mate.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

# Evaluate the mate output as a full derivation path (this previously failed
# because mate.extraPackages now throws).
[[ "$(nix eval --raw ".#nixosConfigurations.${MATE_OUTPUT}.config.system.build.toplevel.drvPath")" ]] || fail "could not evaluate ${MATE_OUTPUT}.config.system.build.toplevel.drvPath"

packages="$(nix eval --json ".#nixosConfigurations.${MATE_OUTPUT}.config.environment.systemPackages")"

# Convert to package name list (drop store hash prefix + trailing version suffix)
package_names="$(printf '%s\n' "$packages" | jq -r '.[] | split("/")[-1] | sub("^[0-9a-z]{32}-"; "") | sub("-[0-9][0-9A-Za-z._+~:-]*$"; "")')"

# Strictly enforce migrated addition set and multiplicity in tests.
explicit_additions=(
  mate-applets
  mate-icon-theme-faenza
  atril
  caja-extensions
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

duplicitous=$(printf '%s\n' "${explicit_additions[@]}" | sort | uniq -d)
if [[ -n "$duplicitous" ]]; then
  fail "migrated explicit additions contain duplicates: ${duplicitous//$'\n'/, }"
fi

# Avoid duplicate explicit `mate-applets` in profile itself.
mate_applets_profile="$(grep -o 'mate-applets' "$MATE_PROFILE" | wc -l)"
[[ "$mate_applets_profile" -eq 1 ]] || fail "mate.nix explicit mate-applets should appear exactly once"

# Preserve explicit additions as a set and ensure each is present in the built system.
for pkg in "${explicit_additions[@]}"; do
  present="$(grep -Fx -c "$pkg" <<<"$package_names")"
  if [[ "$present" -lt 1 ]]; then
    fail "${MATE_OUTPUT} missing migrated package ${pkg}"
  fi
done

for excluded in mate-user-share caja; do
  if grep -Fxq "$excluded" <<<"$package_names"; then
    fail "${MATE_OUTPUT} unexpectedly includes ${excluded}"
  fi
done

if grep -q 'caja-with-extensions' "$MATE_PROFILE"; then
  fail "${MATE_OUTPUT} profile explicitly lists redundant caja-with-extensions"
fi

if grep -q 'mate-applets' "$MATE_PROFILE" && [[ "$mate_applets_profile" -ne 1 ]]; then
  fail "mate.nix should contain exactly one mate-applets explicit package line"
fi
echo "PASS: mate profile configuration retains strict migrated package set"
