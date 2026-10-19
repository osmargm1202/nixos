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

jq -e '.aliases == {}' <<<"$inventory_json" >/dev/null \
  || fail 'desktop aliases must not be public outputs'

jq -e '
  [.configurations | to_entries[] | {key: .key, host: .value.hostName,
    user: .value.userName, desktop: .value.profileName}] == [
    {key: "envy", host: "envy", user: "osmarg", desktop: "sway"},
    {key: "ero", host: "ero", user: "osmarg", desktop: "i3"},
    {key: "jarq", host: "jarq", user: "jarq", desktop: "i3"},
    {key: "lenovo", host: "lenovo", user: "osmarg", desktop: "ryoku"},
    {key: "orgm", host: "orgm", user: "osmarg", desktop: "hyprland"},
    {key: "orgm-ryoku", host: "orgm", user: "osmarg", desktop: "ryoku"}
  ]
' <<<"$inventory_json" >/dev/null \
  || fail 'canonical host, user or desktop selection changed'

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

printf 'PASS: five hosts plus retained orgm-ryoku inventory\n'
