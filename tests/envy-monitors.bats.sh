#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Regression: missing host seed or disabling the internal panel would send
# workspace focus/cursor onto the phantom DP-1 output on this laptop.
source="$ROOT/dotfiles/config/hosts/envy/profiles/ryoku/.config/orgm-ryoku/monitors_user.lua"
if [[ ! -f "$source" ]]; then
  echo "FAIL: envy has no persistent phantom-output policy" >&2
  exit 1
fi
lua="$(bash "$ROOT/tests/helpers/declared-lua.sh" "$ROOT")"
"$lua" - "$source" <<"LUA"
local disabled = {}
hl = { monitor = function(rule)
    assert(not rule.disabled or rule.output ~= "", "must not disable all external outputs")
    disabled[rule.output] = rule.disabled == true
end }
dofile(arg[1])
assert(disabled["DP-1"], "phantom DP-1 must not receive workspaces")
assert(not disabled["eDP-1"], "internal panel must stay usable")
for output, is_disabled in pairs(disabled) do
    assert(not is_disabled or output == "DP-1", "real external outputs must remain available")
end
LUA
printf "PASS: envy keeps its internal panel and excludes only phantom DP-1\n"
