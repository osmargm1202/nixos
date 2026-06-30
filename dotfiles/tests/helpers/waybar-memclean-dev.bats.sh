#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail() { echo "FAIL: $*" >&2; exit 1; }
assert_contains() { grep -Fq "$2" "$1" || fail "expected $2 in $1"; }

SCRIPT="$ROOT/config/shared/.local/bin/memclean-dev"
[[ -x "$SCRIPT" ]] || fail "memclean-dev script must exist and be executable"
bash -n "$SCRIPT"

for cfg in "$ROOT/config/shared/.config/waybar/config" "$ROOT/config/shared/.config/waybar-hypr/config"; do
  assert_contains "$cfg" '"custom/memclean"'
  assert_contains "$cfg" '"exec": "memclean-dev status"'
  assert_contains "$cfg" '"on-click": "memclean-dev clean"'
  assert_contains "$cfg" '"return-type": "json"'
done

for css in "$ROOT/config/shared/.config/waybar/style.css" "$ROOT/config/shared/.config/waybar-hypr/style.css"; do
  assert_contains "$css" '#custom-memclean'
done

assert_contains "$ROOT/config/shared/.config/waybar-hypr/style.css" 'icons/memclean.svg'
[[ -f "$ROOT/config/shared/.config/waybar-hypr/icons/memclean.svg" ]] || fail "memclean icon missing"

assert_contains "$ROOT/config/dotfiles.json" '".local/bin/memclean-dev"'

# Safety gates: script must target requested dev memory hogs and protect forbidden apps.
assert_contains "$SCRIPT" 'lua-language-server'
assert_contains "$SCRIPT" 'pylance'
assert_contains "$SCRIPT" 'claude'
assert_contains "$SCRIPT" '.pi/agent'
assert_contains "$SCRIPT" 'zen-browser'
assert_contains "$SCRIPT" 'steamwebhelper'
assert_contains "$SCRIPT" 'qemu-system'
assert_contains "$SCRIPT" 'appid=570'

STATUS="$($SCRIPT status)"
[[ "$STATUS" == *'"text"'* ]] || fail "status must output waybar JSON"
[[ "$STATUS" == *'"tooltip"'* ]] || fail "status must include tooltip"

DRY="$($SCRIPT dry-run)"
[[ "$DRY" == *'Protected patterns'* ]] || fail "dry-run must show protected patterns"

echo "waybar memclean dev test passed"
