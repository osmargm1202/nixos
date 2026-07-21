#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPO="$(cd "$ROOT/.." && pwd)"
MONITORS="$ROOT/config/profiles/hyprland/.config/hypr/lua/monitors.lua"
WORKSPACES="$ROOT/config/profiles/hyprland/.config/hypr/lua/runtime-workspaces.lua"
HYPRLAND="$ROOT/config/profiles/hyprland/.config/hypr/hyprland.lua"
DOTFILES_MODULE="$REPO/nixos/common-dotfiles.nix"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

LUA_OUT="$(nix build --no-link --print-out-paths "$REPO#nixosConfigurations.lenovo-hyprland.pkgs.lua")"
LUA="$LUA_OUT/bin/lua"

run_monitors() {
  HOME="$TMP/home" HOSTNAME="testhost" "$LUA" - "$MONITORS" <<'LUA'
local module = arg[1]
hl = {
  calls = {},
  monitor = function(rule)
    table.insert(hl.calls, rule.output)
  end,
}
dofile(module)
for _, output in ipairs(hl.calls) do
  if output == "" then output = "<generic>" end
  print(output)
end
LUA
}

mkdir -p "$TMP/home/.config/hypr/lua/monitors"
printf 'hl.monitor({ output = "RUNTIME" })\n' > "$TMP/home/.config/hypr/monitors.lua"
printf 'hl.monitor({ output = "HOST" })\n' > "$TMP/home/.config/hypr/lua/monitors/testhost.lua"
[ "$(run_monitors)" = 'RUNTIME' ] || fail 'runtime monitors.lua must take precedence over host layout'

rm "$TMP/home/.config/hypr/monitors.lua"
[ "$(run_monitors)" = 'HOST' ] || fail 'host layout must load when runtime layout is absent'

rm "$TMP/home/.config/hypr/lua/monitors/testhost.lua"
[ "$(run_monitors)" = '<generic>' ] || fail 'generic monitor fallback must load when runtime and host layouts are absent'

printf 'this is invalid lua !!!\n' > "$TMP/home/.config/hypr/monitors.lua"
printf 'hl.monitor({ output = "HOST" })\n' > "$TMP/home/.config/hypr/lua/monitors/testhost.lua"
if run_monitors >/dev/null 2>&1; then
  fail 'malformed runtime monitors.lua must surface a config error instead of silently using host fallback'
fi

[ -f "$WORKSPACES" ] || fail 'runtime-workspaces.lua must exist'
grep -Fq 'require("lua.runtime-workspaces")' "$HYPRLAND" || fail 'hyprland.lua must load optional runtime workspaces'
grep -Fq '".config/hypr/lua/runtime-workspaces.lua"' "$DOTFILES_MODULE" ||
  fail 'Home Manager must deploy the tracked runtime workspace loader'

printf 'hl.workspace_rule({ workspace = "9" })\n' > "$TMP/home/.config/hypr/workspaces.lua"
workspace_output="$(HOME="$TMP/home" "$LUA" - "$WORKSPACES" <<'LUA'
local module = arg[1]
hl = {
  workspace_rule = function(rule)
    print(rule.workspace)
  end,
}
dofile(module)
LUA
)"
[ "$workspace_output" = '9' ] || fail 'runtime workspaces.lua must load when present'

rm "$TMP/home/.config/hypr/workspaces.lua"
workspace_output="$(HOME="$TMP/home" "$LUA" - "$WORKSPACES" <<'LUA'
local module = arg[1]
hl = {
  workspace_rule = function(rule)
    print(rule.workspace)
  end,
}
dofile(module)
LUA
)"
[ -z "$workspace_output" ] || fail 'workspace loader must be a no-op when runtime file is absent'

printf 'PASS: Hyprland consumes NWG Lua with safe fallbacks\n'
