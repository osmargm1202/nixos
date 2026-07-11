#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE="$REPO_DIR/nixos/binary-cache.nix"
FLAKE="$REPO_DIR/flake.nix"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[[ -f "$MODULE" ]] || fail "nixos/binary-cache.nix must exist"

grep -Fq 'https://orgm.cachix.org' "$MODULE" \
  || fail "orgm Cachix substituter must be configured"
grep -Fq 'orgm.cachix.org-1:8Be6uDm2ivJw4MPJBuCaoJfZtfp6RBbjh2IzI4JmqVA=' "$MODULE" \
  || fail "orgm Cachix public key must be trusted"
grep -Fq 'cachix watch-exec --watch-mode post-build-hook orgm' "$MODULE" \
  || fail "publisher wrapper must upload only paths built by its command"
grep -Fq 'orgm-cache-run' "$MODULE" \
  || fail "publisher wrapper must be installed as orgm-cache-run"
grep -Fq 'trusted-users = [ "root" "@wheel" ];' "$MODULE" \
  || fail "wheel users must be trusted to register the Cachix post-build hook"

if grep -Eq 'CACHIX_AUTH_TOKEN|authToken|signingKey' "$MODULE"; then
  fail "repository module must not contain Cachix secrets"
fi

references=$(grep -Fc './nixos/binary-cache.nix' "$FLAKE")
[[ "$references" -eq 6 ]] \
  || fail "all six NixOS construction paths must import binary-cache.nix (found $references)"

echo "PASS: binary cache configuration tests"
