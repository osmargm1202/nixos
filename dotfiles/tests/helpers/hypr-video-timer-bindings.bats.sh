#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CLASSIC="$ROOT/config/profiles/hyprland/.config/hypr/lua/keybindings.lua"
I3="$ROOT/config/profiles/i3/.config/i3/config"
LABWC="$ROOT/config/profiles/labwc/.config/labwc/rc.xml"

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
  '  hl.bind(mainMod .. " + mouse:274", hl.dsp.focus({ workspace = "r-1" }))' \
  "classic previous-workspace wheel"
assert_once "$CLASSIC" \
  '  hl.bind(mainMod .. " + mouse:275", hl.dsp.focus({ workspace = "r+1" }))' \
  "classic next-workspace wheel"

assert_once "$I3" \
  'bindsym $mod+Shift+Tab exec --no-startup-id hypr-video-timer --backend i3' \
  "i3 timer"
assert_once "$LABWC" \
  '    <keybind key="W-S-Tab">' \
  "Labwc timer"
assert_once "$LABWC" \
  '        <command>hypr-video-timer --backend labwc</command>' \
  "Labwc timer command"
assert_once "$LABWC" \
  '    <keybind key="W-C-Tab">' \
  "Labwc timer return binding"
assert_once "$LABWC" \
  '      <action name="GoToDesktop" to="last"/>' \
  "Labwc timer return action"

echo "hypr video timer binding tests passed"
