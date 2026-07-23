#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE="$REPO_DIR/nixos/binary-cache.nix"
FIXTURE="$REPO_DIR/tests/fixtures/nixos-configurations.txt"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_includes() {
  local json_path="$1" expected="$2" target="$3"
  jq -e "index(\"$expected\")" <<<"$json_path" >/dev/null || fail "$target"
}

assert_any_path_suffix() {
  local json_path="$1" suffix="$2" target="$3"
  jq -e --arg suffix "$suffix" '
    any(.[];
      (split("/")[-1] | sub("^[0-9a-z]{32}-"; "") ) as $pkg
      | (($pkg == $suffix) or ($pkg | test("^" + $suffix + "-[0-9]")))
    )
  ' <<<"$json_path" >/dev/null || fail "$target"
}

[[ -f "$MODULE" ]] || fail "nixos/binary-cache.nix must exist"
[[ -f "$FIXTURE" ]] || fail "fixtures file missing: $FIXTURE"

# Module-level checks (documented payload expectations)
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

# Verified behavior: every public configuration resolves from mkSystem and therefore
# inherits the binary-cache module.
while IFS= read -r output; do
  [[ -z "$output" ]] && continue

  substituters="$(nix eval --json ".#nixosConfigurations.${output}.config.nix.settings.substituters" )"
  public_keys="$(nix eval --json ".#nixosConfigurations.${output}.config.nix.settings.trusted-public-keys" )"
  trusted_users="$(nix eval --json ".#nixosConfigurations.${output}.config.nix.settings.trusted-users" )"
  system_packages="$(nix eval --json ".#nixosConfigurations.${output}.config.environment.systemPackages" )"

  assert_includes "$substituters" 'https://orgm.cachix.org' "$output is missing cachix substituter"
  assert_includes "$public_keys" 'orgm.cachix.org-1:8Be6uDm2ivJw4MPJBuCaoJfZtfp6RBbjh2IzI4JmqVA=' "$output is missing cachix key"
  jq -e 'any(.[]; . == "root") and any(.[]; . == "@wheel")' <<<"$trusted_users" >/dev/null || fail "$output is missing trusted wheel/root users"
  assert_any_path_suffix "$system_packages" 'cachix' "$output is missing cachix package"
  assert_any_path_suffix "$system_packages" 'orgm-cache-run' "$output is missing orgm-cache-run package"
done < "$FIXTURE"

echo "PASS: binary cache configuration tests"
