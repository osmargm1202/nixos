#!/usr/bin/env bash
# Resolve the test interpreter from an explicit override or this flake's lock.
# Do not select an arbitrary store glob or silently skip Lua regressions.
set -euo pipefail
root="${1:?repository root required}"
if [[ -n "${ORGM_TEST_LUA:-}" ]]; then
  interpreter="$(command -v -- "$ORGM_TEST_LUA")" || {
    printf 'FAIL: ORGM_TEST_LUA is not executable: %s\n' "$ORGM_TEST_LUA" >&2
    exit 1
  }
else
  interpreter="$(ORGM_TEST_REPO="$root" nix eval --impure --raw --expr '
    let
      flake = builtins.getFlake ("path:" + builtins.getEnv "ORGM_TEST_REPO");
      pkgs = import flake.inputs.nixpkgs { system = builtins.currentSystem; };
    in "${pkgs.lua5_4}/bin/lua"
  ')"
fi
if [[ ! -x "$interpreter" ]]; then
  printf 'FAIL: Lua interpreter is not available: %s\nSet ORGM_TEST_LUA to an executable Lua 5.4 interpreter.\n' "$interpreter" >&2
  exit 1
fi
printf '%s\n' "$interpreter"
