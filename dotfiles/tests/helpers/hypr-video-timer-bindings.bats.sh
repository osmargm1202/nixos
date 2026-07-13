#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CLASSIC="$ROOT/config/profiles/hyprland/.config/hypr/lua/keybindings.lua"
CAELESTIA="$ROOT/config/profiles/hyprlandqs-caelestia/.config/hypr/lua/keybindings.lua"

fail() { echo "FAIL: $*" >&2; exit 1; }
assert_once() {
  local file="$1"
  local binding="$2"
  local label="$3"
  local count

  count="$(grep -Fxc "$binding" "$file" || true)"
  [[ "$count" -eq 1 ]] || fail "$label binding count is $count, expected 1"
}

assert_once "$CLASSIC" \
  '  hl.bind(mainMod .. " + SHIFT + Tab", hl.dsp.exec_cmd("hypr-video-timer"))' \
  "classic timer"
assert_once "$CLASSIC" \
  '  hl.bind(mainMod .. " + mouse:274", hyprdeck.hyd.dsp.focus({ workspace = "r-1" }))' \
  "classic previous-workspace wheel"
assert_once "$CLASSIC" \
  '  hl.bind(mainMod .. " + mouse:275", hyprdeck.hyd.dsp.focus({ workspace = "r+1" }))' \
  "classic next-workspace wheel"

assert_once "$CAELESTIA" \
  '  hl.bind(mainMod .. " + SHIFT + Tab", hl.dsp.exec_cmd("hypr-video-timer"), { description = "Timed video workspace" })' \
  "Caelestia timer"
assert_once "$CAELESTIA" \
  '  hl.bind(mainMod .. " + mouse:274", hl.dsp.focus({ workspace = "r-1" }), { description = "Previous workspace" })' \
  "Caelestia previous-workspace wheel"
assert_once "$CAELESTIA" \
  '  hl.bind(mainMod .. " + mouse:275", hl.dsp.focus({ workspace = "r+1" }), { description = "Next workspace" })' \
  "Caelestia next-workspace wheel"

suspend_count="$(grep -Ec 'hl\.bind\(mainMod \.\. " \+ ALT \+ P",[[:space:]]+hl\.dsp\.exec_cmd\("systemctl suspend"\)' "$CAELESTIA" || true)"
[[ "$suspend_count" -eq 1 ]] || fail "Caelestia SUPER + ALT + P suspend binding count is $suspend_count, expected 1"

echo "hypr video timer binding tests passed"
