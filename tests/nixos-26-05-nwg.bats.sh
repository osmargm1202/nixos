#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLAKE="$ROOT/flake.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

grep -Fq 'nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";' "$FLAKE" ||
  fail 'primary nixpkgs input must use nixos-26.05'
grep -Fq 'url = "github:nix-community/home-manager/release-26.05";' "$FLAKE" ||
  fail 'Home Manager input must use release-26.05'
grep -Fq 'nixpkgs-zen70.url = "github:NixOS/nixpkgs/25f538306313eae3927264466c70d7001dcea1df";' "$FLAKE" ||
  fail 'Zen 7.0 compatibility input must remain pinned'

state_versions="$(grep -Rh 'stateVersion = "25.11"' "$ROOT/nixos" --include='*.nix' | wc -l)"
[ "$state_versions" -eq 5 ] || fail 'all five stateVersion declarations must remain 25.11'
if grep -R 'stateVersion = "26.05"' "$ROOT/nixos" --include='*.nix' -q; then
  fail 'release upgrade must not change stateVersion to 26.05'
fi

profiles=(
  lenovo-labwc
  lenovo-gnome
  lenovo-hyprland
  lenovo-hyprlandqs-caelestia
  lenovo-i3
  lenovo-xfce
  lenovo-mate
)

for profile in "${profiles[@]}"; do
  release="$(nix eval --raw "$ROOT#nixosConfigurations.$profile.config.system.nixos.release")"
  [ "$release" = '26.05' ] || fail "$profile must evaluate NixOS release 26.05 (got $release)"

  kernel="$(nix eval --raw "$ROOT#nixosConfigurations.$profile.config.boot.kernelPackages.kernel.version")"
  [[ "$kernel" = 6.12.* ]] || fail "$profile must remain on Linux 6.12 LTS (got $kernel)"

done

nwg="$(nix eval --raw "$ROOT#nixosConfigurations.lenovo-hyprland.pkgs.nwg-displays.version")"
[ "$nwg" = '0.4.3' ] || fail "lenovo-hyprland must use nwg-displays 0.4.3 (got $nwg)"

printf 'PASS: NixOS 26.05 provides NWG Displays 0.4.3 on Lenovo LTS\n'
