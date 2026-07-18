#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/config/profiles/hyprland/.local/bin/hypr-current-wallpaper"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p \
  "$TMP/home/.config/wallpapers" \
  "$TMP/cache/skwd-wall/wallpaper" \
  "$TMP/runtime"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

fallback="$TMP/home/.config/wallpapers/xnm1-background.png"
current="$TMP/cache/skwd-wall/wallpaper/current.jpg"
printf 'fallback\n' >"$fallback"
printf 'skwd\n' >"$current"

output="$(HOME="$TMP/home" XDG_CACHE_HOME="$TMP/cache" XDG_RUNTIME_DIR="$TMP/runtime" "$SCRIPT")"
[ "$output" = "$TMP/runtime/hypr-current-wallpaper" ] || fail "helper must print runtime link"
[ "$(readlink "$output")" = "$current" ] || fail "lockscreen must prefer Skwd current.jpg"

rm -f "$current"
HOME="$TMP/home" XDG_CACHE_HOME="$TMP/cache" XDG_RUNTIME_DIR="$TMP/runtime" "$SCRIPT" >/dev/null
[ "$(readlink "$TMP/runtime/hypr-current-wallpaper")" = "$fallback" ] || fail "lockscreen must preserve fallback"

if rg -q 'waytrogen|hypr-random-wallpaper' "$SCRIPT"; then
  fail "lockscreen bridge must not read legacy wallpaper state"
fi

printf 'PASS: Hyprlock follows Skwd current image\n'
