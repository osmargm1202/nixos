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

: >"$tmp/calls"
CAPTURE="$tmp/calls" FLATPAK_BIN="$tmp/flatpak" \
  "$discord_out/bin/discord" --force-webrtc-ip-handling-policy=bad_public --start-minimized
[[ "$(grep -Fxc -- "$POLICY" "$tmp/calls")" == 1 ]] \
  || fail 'Discord wrapper must normalize conflicting policy to required policy'
grep -Fq -- '--force-webrtc-ip-handling-policy=bad_public' "$tmp/calls" \
  && fail 'Discord wrapper leaked conflicting policy value'

if CAPTURE="$tmp/calls" FLATPAK_BIN="$tmp/flatpak" FLATPAK_INFO_FAIL=1 \
  "$discord_out/bin/discord" 2>"$tmp/error"; then
  fail 'Discord wrapper accepted a missing Flatpak app'
fi
grep -Fq 'Discord Flatpak com.discordapp.Discord is not installed' "$tmp/error" \
  || fail 'Discord wrapper missing installation error'

grep -RFq -- "$POLICY" "$vesktop_out/bin" \
  || fail 'Vesktop wrapper missing policy'

grep -Fq './vesktop.nix' "$ROOT/nixos/profiles/common_hyprland.nix" \
  || fail 'common Hyprland profile does not import vesktop module'
if grep -Eq '^[[:space:]]+vesktop[[:space:]]*$' "$ROOT/nixos/profiles/common_hyprland.nix"; then
  fail 'raw Vesktop package remains in common Hyprland package list'
fi

for profile in orgm-hyprland orgm-hyprlandqs-caelestia; do
  packages="$(cd "$ROOT" && nix eval ".#nixosConfigurations.$profile.config.environment.systemPackages" --json)"
  jq -e 'any(.[]; test("vesktop-webrtc-"))' <<<"$packages" >/dev/null \
    || fail "wrapped Vesktop missing from $profile"
  jq -e 'any(.[]; test("discord"))' <<<"$packages" >/dev/null \
    || fail "Discord wrapper missing from $profile"
done

exec_line="$(cd "$ROOT" && nix eval --raw \
  '.#nixosConfigurations.orgm-hyprland.config.home-manager.users.osmarg.xdg.desktopEntries."com.discordapp.Discord".exec')"
[[ "$exec_line" == */bin/discord\ %U ]] \
  || fail "unexpected Discord desktop Exec: $exec_line"

helper="$ROOT/dotfiles/config/profiles/hyprland/.local/bin/hypr-start-discord"
grep -Fq 'command -v Discord' "$helper" \
  || fail 'uppercase Discord fallback missing'
[[ "$(grep -Fc '"$policy"' "$helper")" == 3 ]] \
  || fail 'not every Discord autostart branch carries policy'

echo 'PASS: Discord and Vesktop wrappers enforce WebRTC policy'
