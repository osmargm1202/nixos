#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INVENTORY="$ROOT/configurations.nix"
EXPECTED="$ROOT/tests/fixtures/nixos-configurations.txt"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

inventory_json="$(nix eval --json --file "$INVENTORY")"
actual_names="$(
  jq -r '[(.configurations | keys[]), (.aliases | keys[])] | sort | .[]' \
    <<<"$inventory_json"
)"

diff -u "$EXPECTED" <(printf '%s\n' "$actual_names") \
  || fail 'inventory names differ from public output baseline'

jq -e '
  .aliases == {
    jarq: "jarq-hyprland",
    lenovo: "lenovo-hyprland",
    orgm: "orgm-hyprland"
  }
' <<<"$inventory_json" >/dev/null \
  || fail 'alias map changed'

jq -e '
  all(.configurations[];
    (.role == "desktop" or .role == "terminal" or .role == "server")
    and (.hostName | type == "string")
    and (.hardware | type == "string")
    and (.userName | type == "string")
    and (.extraModules | type == "array")
    and (if .role == "desktop"
         then (.profile | type == "string") and (.profileName | type == "string")
         else (has("profile") | not) and (has("profileName") | not)
         end)
  )
' <<<"$inventory_json" >/dev/null \
  || fail 'configuration specs do not match normalized schema'

[[ "$(jq -r '.configurations["ero-server"].hostName' <<<"$inventory_json")" == 'ero' ]] \
  || fail 'ero-server hostname changed'
[[ "$(jq -r '.configurations["jarq-hyprland"].userName' <<<"$inventory_json")" == 'jarq' ]] \
  || fail 'jarq user changed'
[[ "$(jq -r '.configurations["orgm-hyprland"].extraModules | length' <<<"$inventory_json")" == '2' ]] \
  || fail 'orgm desktop extras changed'

printf 'PASS: explicit configuration inventory\n'
