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

assert_executable() {
  local name="$1"
  [ -x "$BIN/$name" ] || fail "$name is not executable"
}

assert_syntax() {
  local name="$1"
  bash -n "$BIN/$name" || fail "$name syntax check failed"
}

for helper in \
  brightness-osd \
  volume-osd \
  mic-volume-osd \
  hypr-random-wallpaper \
  hypr-app-launcher \
  hypr-bluetooth-reconnect \
  hypr-display-targets \
  hypr-focus-notification-app \
  hypr-main-menu \
  hypr-power-menu \
  waybar-date-es \
  waybar-day-month-es \
  waybar-time-ampm \
  waybar-swap-usage \
  waybar-watch; do
  assert_executable "$helper"
  assert_syntax "$helper"
done

rg -q "! -name 'orgm-current.css'" "$BIN/waybar-watch" || \
  fail "waybar-watch should not restart Waybar for generated orgm-current.css theme updates"

echo "hypr shell helper smoke tests passed"
