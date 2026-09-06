#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/config/shared/.local/bin/memclean-dev"
fail() { echo "FAIL: $*" >&2; exit 1; }

[[ -x "$SCRIPT" ]] || fail "memclean-dev script must exist and be executable"

STATUS="$("$SCRIPT" status)"
python3 - "$STATUS" <<'PY' || fail "status must emit Waybar JSON with a tooltip and state"
import json
import sys

status = json.loads(sys.argv[1])
assert isinstance(status["text"], str) and status["text"]
assert isinstance(status["tooltip"], str) and status["tooltip"]
assert status["class"] in {"idle", "active"}
PY

DRY="$("$SCRIPT" dry-run)"
[[ "$DRY" == *'Protected patterns'* ]] || fail "dry-run must describe protected processes"

if "$SCRIPT" invalid >/dev/null 2>&1; then
  fail "invalid mode must fail"
fi

echo "waybar memclean dev test passed"
