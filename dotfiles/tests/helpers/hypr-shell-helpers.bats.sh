#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SHARED_BIN="$ROOT/config/shared/.local/bin"
PROFILE_BIN="$ROOT/config/profiles/hyprland/.local/bin"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

helper_path() {
  local name="$1"
  if [ -e "$PROFILE_BIN/$name" ]; then
    printf '%s\n' "$PROFILE_BIN/$name"
  else
    printf '%s\n' "$SHARED_BIN/$name"
  fi
}

assert_executable() {
  local name="$1"
  local path
  path="$(helper_path "$name")"
  [ -x "$path" ] || fail "$name is not executable"
}

assert_syntax() {
  local name="$1"
  local path
  path="$(helper_path "$name")"
  bash -n "$path" || fail "$name syntax check failed"
}

for helper in \
  brightness-osd \
  volume-osd \
  mic-volume-osd \
  hypr-skwd-wall-start \
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

echo "hypr shell helper smoke tests passed"
