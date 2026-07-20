#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POLICY='--force-webrtc-ip-handling-policy=default_public_and_private_interfaces'

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

build_package() {
  local package_file="$1"
  (
    cd "$ROOT"
    nix build --no-link --print-out-paths --impure --expr "
      let
        flake = builtins.getFlake (toString ./.);
        pkgs = flake.nixosConfigurations.orgm-hyprland.pkgs;
      in pkgs.callPackage ./$package_file {}
    "
  )
}

discord_out="$(build_package nixos/packages/discord-webrtc.nix)"
vesktop_out="$(build_package nixos/packages/vesktop-webrtc.nix)"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cat >"$tmp/flatpak" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" >>"$CAPTURE"
if [[ "${1:-}" == info ]]; then
  [[ "${FLATPAK_INFO_FAIL:-0}" == 1 ]] && exit 1
  exit 0
fi
EOF
chmod +x "$tmp/flatpak"

CAPTURE="$tmp/calls" FLATPAK_BIN="$tmp/flatpak" \
  "$discord_out/bin/discord" --start-minimized
[[ "$(grep -Fxc -- "$POLICY" "$tmp/calls")" == 1 ]] \
  || fail 'Discord wrapper must add policy exactly once'
grep -Fxq -- '--start-minimized' "$tmp/calls" \
  || fail 'Discord wrapper dropped caller argument'

: >"$tmp/calls"
CAPTURE="$tmp/calls" FLATPAK_BIN="$tmp/flatpak" \
  "$discord_out/bin/discord" "$POLICY" --start-minimized
[[ "$(grep -Fxc -- "$POLICY" "$tmp/calls")" == 1 ]] \
  || fail 'Discord wrapper duplicated supplied policy'

if CAPTURE="$tmp/calls" FLATPAK_BIN="$tmp/flatpak" FLATPAK_INFO_FAIL=1 \
  "$discord_out/bin/discord" 2>"$tmp/error"; then
  fail 'Discord wrapper accepted a missing Flatpak app'
fi
grep -Fq 'Discord Flatpak com.discordapp.Discord is not installed' "$tmp/error" \
  || fail 'Discord wrapper missing installation error'

grep -RFq -- "$POLICY" "$vesktop_out/bin" \
  || fail 'Vesktop wrapper missing policy'

echo 'PASS: Discord and Vesktop wrappers enforce WebRTC policy'
