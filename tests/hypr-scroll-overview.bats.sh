#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 "$ROOT/tests/hypr-scroll-overview.test.py"
python3 "$ROOT/tests/hypr-scroll-overview-package.test.py"
lua="${ORGM_TEST_LUA:-$(command -v lua || true)}"
if [[ -z "$lua" ]]; then
  printf '%s\n' 'SKIP: adjacent binding/startup regression requires Lua'
else
  "$lua" "$ROOT/tests/hypr-sway-bindings.lua" "$ROOT"
fi
printf '%s\n' 'hypr-scroll-overview: pinned native plugin with Quickshell fallback'
