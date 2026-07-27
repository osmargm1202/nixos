#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  printf '%s\n' "$1" >&2
  exit 1
}

for profile in orgm-cinnamon orgm-i3; do
  if ! packages="$(nix eval --json "${REPO_DIR}#nixosConfigurations.${profile}.config.environment.systemPackages")"; then
    fail "$profile"
  fi

  if ! jq -e 'any(.[]; test("-xclip-[^/]+$"))' <<<"$packages" >/dev/null; then
    fail "$profile"
  fi
done

printf 'PASS: orgm-cinnamon and orgm-i3 include xclip\n'
