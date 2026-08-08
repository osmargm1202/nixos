#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT/nixos/profiles/i3.nix"
FIREFOX="$ROOT/nixos/firefox.nix"
HELPER="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-firefox-new-window"
DOTFILES="$ROOT/nixos/common-dotfiles.nix"
DISCORD="$ROOT/nixos/packages/discord-webrtc.nix"
VESKTOP="$ROOT/nixos/packages/vesktop-webrtc.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

grep -Fq './firefox.nix' "$ROOT/nixos/common.nix" ||
  fail 'common configuration must import Firefox'
grep -Fq 'enable = true;' "$FIREFOX" ||
  fail 'Firefox must be enabled'
! grep -Fq 'chromium' "$PROFILE" ||
  fail 'i3 must not install or select Chromium'

for mime in \
  text/html \
  application/xhtml+xml \
  x-scheme-handler/http \
  x-scheme-handler/https; do
  grep -Fq "\"$mime\" = [ \"firefox.desktop\" ];" "$FIREFOX" ||
    fail "Firefox must handle $mime"
done

[[ -x "$HELPER" ]] || fail 'Firefox i3 helper missing or not executable'
grep -Fq '".local/bin/i3-firefox-new-window"' "$DOTFILES" ||
  fail 'Firefox i3 helper not deployed'
bash -n "$HELPER"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
cat >"$tmp/bin/firefox-open-tab" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$FIREFOX_TAB_ARGS"
EOF
chmod +x "$tmp/bin/firefox-open-tab"
FIREFOX_TAB_ARGS="$tmp/args" PATH="$tmp/bin:$PATH" "$HELPER"
[[ "$(<"$tmp/args")" == '--new' ]] ||
  fail 'Firefox i3 helper must request a new tab from the shared helper'
FIREFOX_TAB_ARGS="$tmp/args" PATH="$tmp/bin:$PATH" "$HELPER" https://example.com/
[[ "$(<"$tmp/args")" == '--new https://example.com/' ]] ||
  fail 'Firefox i3 helper must forward URLs while requesting a new tab'

grep -Fq -- '--force-webrtc-ip-handling-policy=default_public_and_private_interfaces' "$DISCORD" ||
  fail 'Discord WebRTC network policy disappeared'
grep -Fq -- '--force-webrtc-ip-handling-policy=default_public_and_private_interfaces' "$VESKTOP" ||
  fail 'Vesktop WebRTC network policy disappeared'
grep -Fq -- '--disable-features=WebRtcAllowInputVolumeAdjustment' "$VESKTOP" ||
  fail 'Vesktop microphone gain policy disappeared'

printf 'PASS: i3 uses Firefox and retains WebRTC-protected communication apps\n'
