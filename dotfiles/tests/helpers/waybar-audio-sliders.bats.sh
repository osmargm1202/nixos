#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

assert_contains() {
  local file="$1"
  local expected="$2"
  if ! grep -Fq "$expected" "$file"; then
    echo "FAIL: expected in $file:" >&2
    echo "$expected" >&2
    exit 1
  fi
}

for cfg in "$ROOT/config/shared/.config/waybar/config" "$ROOT/config/shared/.config/waybar-hypr/config"; do
  assert_contains "$cfg" '"pulseaudio"'
  assert_contains "$cfg" '"pulseaudio/slider"'
  assert_contains "$cfg" '"pulseaudio#microphone"'
  assert_contains "$cfg" '"pulseaudio/slider#microphone"'
  assert_contains "$cfg" '"target": "source"'
  assert_contains "$cfg" '"format": "{icon}"'
  assert_contains "$cfg" '"format-muted": "󰝟"'
  assert_contains "$cfg" '"format": "{format_source}"'
  assert_contains "$cfg" '"format-source": "󰍬"'
  assert_contains "$cfg" '"format-source-muted": "󰍭"'
  assert_contains "$cfg" '"on-click": "pamixer -t"'
  assert_contains "$cfg" '"on-click": "pamixer --default-source -t"'
  assert_contains "$cfg" '"on-click-right": "pavucontrol"'
  assert_contains "$cfg" '"max": 150'
done

for css in "$ROOT/config/shared/.config/waybar/style.css" "$ROOT/config/shared/.config/waybar-hypr/style.css"; do
  assert_contains "$css" '#pulseaudio { color: @blue; font-size: 20px; }'
  assert_contains "$css" '#pulseaudio:not(.microphone).muted { color: @red; }'
  assert_contains "$css" '#pulseaudio.microphone.source-muted { color: @red; }'
  assert_contains "$css" '#pulseaudio-slider'
  assert_contains "$css" '#pulseaudio-slider trough'
  assert_contains "$css" 'linear-gradient(to right, @surface0 0%, @surface0 65.8%, @panel_border 65.8%, @panel_border 67.5%, @surface0 67.5%, @surface0 100%)'
  assert_contains "$css" '#pulseaudio-slider highlight'
  assert_contains "$css" '#pulseaudio-slider.microphone.muted highlight,'
  assert_contains "$css" '#pulseaudio-slider.microphone.source-muted highlight'
done

echo "waybar audio sliders smoke test passed"
