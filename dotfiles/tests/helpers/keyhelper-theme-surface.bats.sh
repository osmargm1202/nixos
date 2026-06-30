#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
qml="$root/config/shared/.config/quickshell/modules/keyhelper/shell.qml"
fail() { echo "FAIL: $*" >&2; exit 1; }

[ -f "$qml" ] || fail "keyhelper QML missing"

if grep -n 'color: root\.theme\.onAccent' "$qml"; then
  fail "keyhelper must not use onAccent as a surface background"
fi

grep -q 'color: root\.theme\.buttonSoft' "$qml" || fail "keyhelper sidebar should use buttonSoft surface"
grep -q 'color: root\.theme\.eventCard' "$qml" || fail "keyhelper rows should use eventCard surface"

echo "PASS: keyhelper surfaces use theme surfaces, not onAccent"
