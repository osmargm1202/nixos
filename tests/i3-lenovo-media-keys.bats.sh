#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"
WIFI="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-wifi-toggle"
DOTFILES="$ROOT/nixos/common-dotfiles.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

for binding in \
  'XF86AudioRaiseVolume exec --no-startup-id $run volume-osd up' \
  'XF86AudioLowerVolume exec --no-startup-id $run volume-osd down' \
  'XF86AudioMute exec --no-startup-id $run volume-osd mute' \
  'XF86AudioMicMute exec --no-startup-id $run mic-volume-osd mute' \
  'XF86MonBrightnessUp exec --no-startup-id $run brightness-osd up' \
  'XF86MonBrightnessDown exec --no-startup-id $run brightness-osd down' \
  'XF86WLAN exec --no-startup-id $run i3-wifi-toggle' \
  'XF86RFKill exec --no-startup-id $run i3-wifi-toggle'; do
  grep -Fq "$binding" "$CONFIG" || fail "missing Lenovo media binding: $binding"
done

[ -x "$WIFI" ] || fail 'i3-wifi-toggle missing or not executable'
grep -Fq 'nmcli radio wifi off' "$WIFI" || fail 'Wi-Fi disable action missing'
grep -Fq 'nmcli radio wifi on' "$WIFI" || fail 'Wi-Fi enable action missing'
grep -Fq '".local/bin/i3-wifi-toggle"' "$DOTFILES" || fail 'Wi-Fi helper not deployed'
bash -n "$WIFI"

printf 'PASS: i3 declares Lenovo volume, mic, brightness and Wi-Fi keys\n'
