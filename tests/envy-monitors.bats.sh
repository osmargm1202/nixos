#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Regression: missing host seed or disabling the internal panel would send
# workspace focus/cursor onto the phantom DP-1 output on this laptop.
source=$(nix eval --raw "path:$ROOT#nixosConfigurations.envy.config.home-manager.users.osmarg.home.file" --apply 'files: toString (files.".config/orgm-ryoku/monitors_user.lua".source or "")')
if [[ -z "$source" ]]; then
  echo "FAIL: envy has no persistent phantom-output policy" >&2
  exit 1
fi
lua - "$source" <<"LUA"
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
