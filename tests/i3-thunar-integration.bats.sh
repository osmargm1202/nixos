#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT/nixos/profiles/i3.nix"
MODULE="$ROOT/nixos/common-dotfiles.nix"
I3_ROOT="$ROOT/dotfiles/config/profiles/i3"
UCA="$I3_ROOT/.config/Thunar/uca.xml"
WRAPPER="$I3_ROOT/.local/bin/i3-set-wallpaper"
I3_CONFIG="$I3_ROOT/.config/i3/config"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

grep -Eq '^[[:space:]]+thunar[[:space:]]*$' "$PROFILE" ||
  fail 'i3 must install Thunar'
grep -Fq '<command>i3-set-wallpaper %f</command>' "$UCA" ||
  fail 'Thunar field code %f must be passed to the wallpaper wrapper without quotes'
grep -Fq '<patterns>*.jpg;*.jpeg;*.png;*.webp;*.mp4;*.mkv;*.webm;*.mov;*.m4v;*.avi</patterns>' "$UCA" ||
  fail 'Thunar action must be restricted to i3-wallpaper media formats'
grep -Fq '<image-files/>' "$UCA" ||
  fail 'Thunar action must allow supported images'
grep -Fq '<video-files/>' "$UCA" ||
  fail 'Thunar action must allow supported videos'
grep -Fq 'exec i3-wallpaper --set-active "$1"' "$WRAPPER" ||
  fail 'wallpaper wrapper must quote and forward the selected file'
[[ -x "$WRAPPER" ]] || fail 'wallpaper wrapper source is not executable'

grep -Fq 'profileDotfilesName = if profileName == "i3-minimal" then "i3" else profileName;' "$MODULE" ||
  fail 'i3-minimal must source the i3 dotfile tree'
grep -Fq 'i3-minimal = profileSpecificPaths.i3;' "$MODULE" ||
  fail 'i3-minimal must reuse the exact i3 deployment paths'
grep -Fq 'profileName == "i3" || profileName == "i3-minimal"' "$MODULE" ||
  fail 'i3-minimal must receive the i3 reload activation'

i3_deployment_paths="$(awk '
  /^[[:space:]]+i3 = \[/ { active = 1 }
  active { print }
  active && /^[[:space:]]+\];$/ { exit }
' "$MODULE")"
! grep -qi 'nautilus' <<<"$i3_deployment_paths" ||
  fail 'i3 deployment paths must not include Nautilus actions or launchers'
grep -Fq 'lib.optionalString (profileName == "hyprland")' "$MODULE" ||
  fail 'the real Nautilus wallpaper action must remain exclusive to Hyprland'
grep -Fq '".local/share/nautilus/scripts/Set as Hyprland Wallpaper"' "$MODULE" ||
  fail 'Hyprland must retain its real Nautilus wallpaper action'
grep -Fq 'set $files thunar "$HOME"' "$I3_CONFIG" ||
  fail 'Mod+e must open Thunar'

printf 'PASS: i3 uses Thunar with the quoted active-monitor wallpaper action\n'
