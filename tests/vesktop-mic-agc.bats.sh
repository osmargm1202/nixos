#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT/nixos/profiles/common_hyprland.nix"
FLAG='--disable-features=WebRtcAllowInputVolumeAdjustment'

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	exit 1
}

grep -Fq 'vesktopNoInputVolumeAdjustment' "$PROFILE" ||
	fail 'wrapped Vesktop package is not defined'
grep -Fq -- "$FLAG" "$PROFILE" ||
	fail 'WebRTC input-volume flag is missing'
if grep -Eq 'wpctl[[:space:]]+set-volume[[:space:]]+@DEFAULT_AUDIO_SOURCE@|pactl[[:space:]]+set-source-volume' "$PROFILE"; then
	fail 'profile must not force a microphone volume'
fi

cd "$ROOT"
for profile in orgm-hyprland orgm-hyprlandqs-caelestia; do
	drv="$(nix eval --raw ".#nixosConfigurations.$profile.config.environment.systemPackages" \
		--apply 'packages: let matches = builtins.filter (package: builtins.match "vesktop-no-input-volume-adjustment-.*" package.name != null) packages; in (builtins.head matches).drvPath' \
		2>/dev/null)"
	[[ -n "$drv" ]] || fail "wrapped Vesktop missing from $profile"
	wrapper="$(nix-store -r "$drv" 2>/dev/null)"
	grep -Fq -- "$FLAG" "$wrapper/bin/vesktop" ||
		fail "Vesktop wrapper flag missing from $profile"
done

printf 'PASS: Vesktop cannot adjust physical microphone volume\n'
