#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
I3="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"
DUNST="$ROOT/dotfiles/config/profiles/i3/.config/dunst/dunstrc"
DOTFILES="$ROOT/nixos/common-dotfiles.nix"
SHARED_BIN="$ROOT/dotfiles/config/shared/.local/bin"
HYPR_BIN="$ROOT/dotfiles/config/profiles/hyprland/.local/bin"
CAELESTIA_BIN="$ROOT/dotfiles/config/profiles/hyprlandqs-caelestia/.local/bin"
PROFILE="$ROOT/nixos/profiles/i3.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

if grep -Eq '/home/osmar|/usr/bin' "$DUNST"; then
  fail 'Dunst config contains non-portable absolute paths'
fi
[ ! -d "${DUNST%/*}/icons" ] || fail 'minimal Dunst must use application icons, not fixed urgency assets'
grep -Eq '^[[:space:]]*progress_bar[[:space:]]*=[[:space:]]*true' "$DUNST" ||
  fail 'Dunst progress bar must be enabled for audio OSD'
grep -Eq '^[[:space:]]*mouse_middle_click[[:space:]]*=[[:space:]]*do_action' "$DUNST" ||
  fail 'Dunst notification actions must remain available'

grep -Fq 'bindsym $mod+n exec --no-startup-id dunstctl history-pop' "$I3" ||
  fail 'Dunst history binding missing'
grep -Fq 'bindsym $mod+Shift+n exec --no-startup-id dunstctl set-paused toggle' "$I3" ||
  fail 'Dunst DND binding missing'
grep -Fq 'XF86AudioRaiseVolume exec --no-startup-id $run volume-osd up' "$I3" ||
  fail 'speaker OSD binding missing'
grep -Fq 'XF86AudioMicMute exec --no-startup-id $run mic-volume-osd mute' "$I3" ||
  fail 'microphone OSD binding missing'

for helper in volume-osd mic-volume-osd; do
  [ -x "$SHARED_BIN/$helper" ] || fail "$helper must be shared and executable"
  [ ! -e "$HYPR_BIN/$helper" ] || fail "$helper must not remain Hyprland-owned"
  grep -Fq "    \".local/bin/$helper\"" "$DOTFILES" || fail "$helper missing from shared deployment"
  [ -x "$CAELESTIA_BIN/$helper" ] || fail "Caelestia-specific $helper variant must remain available"
  bash -n "$SHARED_BIN/$helper" "$CAELESTIA_BIN/$helper"
done

grep -Fq 'sp == hp || lib.hasPrefix (hp + "/") sp' "$DOTFILES" ||
  fail 'profile-specific exact paths must override shared Home Manager paths'

grep -Fq 'systemd.user.services.openrgb-notify = lib.mkIf (hostName != "lenovo") {' "$DOTFILES" ||
  fail 'Lenovo must not start the absent G213 notification observer'
if grep -Eq 'swaynotificationcenter|swaync' "$PROFILE" "$I3"; then
  fail 'minimal i3 must use Dunst only'
fi

printf 'PASS: i3 uses portable Dunst controls and shared audio OSD without Lenovo G213\n'
