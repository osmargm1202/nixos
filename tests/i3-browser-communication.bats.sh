#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT/nixos/profiles/i3.nix"
DISCORD="$ROOT/nixos/packages/discord-webrtc.nix"
VESKTOP="$ROOT/nixos/packages/vesktop-webrtc.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

grep -Fq './vesktop.nix' "$PROFILE" ||
  fail 'i3 must retain wrapped Discord and Vesktop applications'
grep -Fq 'zenBrowserFlakeSrc = inputs.zen-browser-flake;' "$PROFILE" ||
  fail 'i3 must build the pinned Zen Browser package'
grep -Eq '^[[:space:]]+zenBrowser[[:space:]]*$' "$PROFILE" ||
  fail 'i3 must install Zen Browser'

for mime in \
  text/html \
  application/xhtml+xml \
  x-scheme-handler/http \
  x-scheme-handler/https; do
  grep -Fq "\"$mime\" = [ \"zen-browser.desktop\" ];" "$PROFILE" ||
    fail "i3 must use Zen Browser for $mime"
done

grep -Fq -- '--force-webrtc-ip-handling-policy=default_public_and_private_interfaces' "$DISCORD" ||
  fail 'Discord WebRTC network policy disappeared'
grep -Fq -- '--force-webrtc-ip-handling-policy=default_public_and_private_interfaces' "$VESKTOP" ||
  fail 'Vesktop WebRTC network policy disappeared'
grep -Fq -- '--disable-features=WebRtcAllowInputVolumeAdjustment' "$VESKTOP" ||
  fail 'Vesktop microphone gain policy disappeared'

printf 'PASS: i3 retains Zen Browser and WebRTC-protected communication apps\n'
