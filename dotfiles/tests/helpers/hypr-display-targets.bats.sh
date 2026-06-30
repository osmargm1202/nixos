#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BIN="$ROOT/config/shared/.local/bin"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

STATE="$TMP/display-targets.json"
MONITORS="$TMP/monitors.json"
GENERATED="$TMP/generated-waybar.json"
export HYPR_DISPLAY_TARGETS_STATE="$STATE"
export HYPR_DISPLAY_TARGETS_MONITORS_JSON="$MONITORS"
export XDG_CACHE_HOME="$TMP/cache"
export PATH="$BIN:$PATH"

cat >"$MONITORS" <<'JSON'
[
  {
    "name": "eDP-1",
    "description": "BOE 0x09DE",
    "make": "BOE",
    "model": "0x09DE",
    "serial": "",
    "focused": true
  }
]
JSON

"$BIN/hypr-display-targets" ensure
jq -e '.monitors["BOE 0x09DE"].primary == true' "$STATE" >/dev/null || fail "single monitor should become primary"

"$BIN/hypr-display-targets" waybar-config "$ROOT/config/shared/.config/waybar-hypr" >"$GENERATED"
[ -s "$GENERATED" ] || fail "waybar-config should print generated config path"
config_path="$(cat "$GENERATED")"
[ -f "$config_path" ] || fail "generated config file missing: $config_path"
jq -e 'all(.[]; has("output") | not)' "$config_path" >/dev/null || fail "single-monitor primary mode should use base config without output"

jq '.waybar.mode = "all"' "$STATE" >"$STATE.tmp" && mv "$STATE.tmp" "$STATE"
"$BIN/hypr-display-targets" waybar-config "$ROOT/config/shared/.config/waybar-hypr" >"$GENERATED"
config_path="$(cat "$GENERATED")"
jq -e 'all(.[]; has("output") | not)' "$config_path" >/dev/null || fail "all mode should omit output"

jq '.waybar.mode = "selected" | .waybar.selected = ["BOE 0x09DE"]' "$STATE" >"$STATE.tmp" && mv "$STATE.tmp" "$STATE"
"$BIN/hypr-display-targets" waybar-config "$ROOT/config/shared/.config/waybar-hypr" >"$GENERATED"
config_path="$(cat "$GENERATED")"
jq -e 'all(.[]; has("output") | not)' "$config_path" >/dev/null || fail "single-monitor selected mode should use base config without output"

"$BIN/hypr-display-targets" dock-env | grep -qx -- '-o eDP-1' || fail "dock-env should target primary output"

printf '{broken json' >"$STATE"
"$BIN/hypr-display-targets" ensure
[ -f "$STATE" ] || fail "state should be recreated after corrupt JSON"
find "$(dirname "$STATE")" -name 'display-targets.json.bak-*' | grep -q . || fail "corrupt state should be backed up"

cat >"$MONITORS" <<'JSON'
[
  {
    "name": "DP-3",
    "description": "LG Electronics LG 2K ABC123",
    "make": "LG Electronics",
    "model": "LG 2K",
    "serial": "ABC123",
    "focused": true
  },
  {
    "name": "eDP-1",
    "description": "BOE 0x09DE",
    "make": "BOE",
    "model": "0x09DE",
    "serial": "",
    "focused": false
  }
]
JSON
"$BIN/hypr-display-targets" ensure
jq -e '.monitors["LG Electronics LG 2K ABC123"] != null and .monitors["BOE 0x09DE"] != null' "$STATE" >/dev/null || fail "ensure should merge known and new monitors"

"$BIN/hypr-display-targets" status >"$TMP/status.txt"
grep -q 'Waybar mode:' "$TMP/status.txt" || fail "status should print waybar mode"

echo "hypr display targets tests passed"
