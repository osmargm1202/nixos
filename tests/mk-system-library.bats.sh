#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

expected_exports='["mkGeneralHost","mkHost","mkMinimalHost","mkProfile","mkServerHost","mkSystem","mkTerminalHost"]'
actual_exports="$(nix eval --json "$ROOT#lib" --apply builtins.attrNames)"
[[ "$actual_exports" == "$expected_exports" ]] \
  || fail "unexpected flake.lib exports: $actual_exports"

general_host="$(
  nix eval --impure --raw --expr "
    let
      flake = builtins.getFlake (toString $ROOT);
    in
    (flake.lib.mkGeneralHost {
      hardware = $ROOT/nixos/hosts/generic/hardware-configuration.nix;
      profile = \"i3\";
      hostName = \"compat-general\";
    }).config.networking.hostName
  "
)"
[[ "$general_host" == 'compat-general' ]] \
  || fail "mkGeneralHost did not evaluate: $general_host"

printf 'PASS: unified system constructor exports\n'
