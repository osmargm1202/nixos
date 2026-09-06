#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIREFOX="$ROOT/nixos/firefox.nix"
CHROMIUM="$ROOT/nixos/chromium.nix"
COMMON="$ROOT/nixos/common.nix"
I3_CONFIG="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"
DISCORD="$ROOT/nixos/packages/discord-webrtc.nix"
VESKTOP="$ROOT/nixos/packages/vesktop-webrtc.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

grep -Fq './firefox.nix' "$COMMON" ||
  fail 'common configuration must import Firefox'
grep -Fq './chromium.nix' "$COMMON" ||
  fail 'common configuration must import Chromium'
grep -Fq 'orgm.chromium.enable = true;' "$COMMON" ||
  fail 'common configuration must enable Chromium for every desktop profile'
grep -Fq 'enable = true;' "$FIREFOX" ||
  fail 'Firefox must be enabled'
grep -Fq 'enableWideVine = true;' "$CHROMIUM" ||
  fail 'Chromium must retain Widevine support'

for mime in text/html application/xhtml+xml; do
  grep -Fq "\"$mime\" = [ \"chromium-browser.desktop\" ];" "$FIREFOX" ||
    fail "Chromium must handle HTML MIME type $mime"
done
for scheme in x-scheme-handler/http x-scheme-handler/https; do
  grep -Fq "\"$scheme\" = [ \"firefox.desktop\" ];" "$FIREFOX" ||
    fail "Firefox must remain the default URL browser for $scheme"
done

grep -Fq 'set $browser $run firefox-open-tab --restore-or-focus' "$I3_CONFIG" ||
  fail 'i3 Win+W must invoke the shared restore-or-focus launcher'

grep -Fq -- '--force-webrtc-ip-handling-policy=default_public_and_private_interfaces' "$DISCORD" ||
  fail 'Discord WebRTC network policy disappeared'
grep -Fq -- '--force-webrtc-ip-handling-policy=default_public_and_private_interfaces' "$VESKTOP" ||
  fail 'Vesktop WebRTC network policy disappeared'
grep -Fq -- '--disable-features=WebRtcAllowInputVolumeAdjustment' "$VESKTOP" ||
  fail 'Vesktop microphone gain policy disappeared'

printf 'PASS: desktop profiles use Chromium for HTML and Firefox for URLs\n'
