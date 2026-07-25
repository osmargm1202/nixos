#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT/nixos/profiles/i3.nix"
DOTFILES_MODULE="$ROOT/nixos/common-dotfiles.nix"
MANIFEST="$ROOT/dotfiles/config/dotfiles.json"
I3_ROOT="$ROOT/dotfiles/config/profiles/i3"
I3_CONFIG="$I3_ROOT/.config/i3/config"

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	exit 1
}

for forbidden in polybar conky waybar 'hypr-'; do
	if grep -Eqi "$forbidden" "$PROFILE" "$I3_CONFIG"; then
		fail "minimal i3 profile still references $forbidden"
	fi
	if grep -REqi "$forbidden" "$I3_ROOT"; then
		fail "minimal i3 dotfile tree still references $forbidden"
	fi
done

! grep -Fq 'bar {' "$I3_CONFIG" || fail 'native i3bar must not accompany the Eww bar'
! grep -Eq 'i3bar_command|status_command|tray_output' "$I3_CONFIG" ||
  fail 'i3bar configuration remains after switching to Eww'
grep -Fq 'systemd.user.services.eww-widgets-sync' "$PROFILE" ||
  fail 'Eww upstream synchronization service missing'
grep -Fq 'systemd.user.services.eww-widgets-bar' "$PROFILE" ||
  fail 'Eww bar service missing'
grep -Fq "sh -c 'dbus-update-activation-environment --systemd DISPLAY XAUTHORITY && systemctl --user start eww-widgets-bar.service'" "$I3_CONFIG" ||
  fail 'i3 does not start the Eww bar after exporting X11 variables'

for path in .config/conky .config/picom .config/polybar; do
	[ ! -e "$I3_ROOT/$path" ] || fail "$path must be removed from i3 dotfiles"
	if grep -Fq "\"$path\"" "$DOTFILES_MODULE"; then
		fail "$path must not be deployed for i3"
	fi
done

for helper in i3-polybar-launch i3-status-battery i3-status-cpu-temp i3-status-gpu-temp; do
	[ ! -e "$I3_ROOT/.local/bin/$helper" ] || fail "$helper must be removed"
	if grep -Fq "\".local/bin/$helper\"" "$DOTFILES_MODULE"; then
		fail "$helper must not be deployed"
	fi
done

jq -e '
  all(.shared.paths[]; . != ".config/conky" and . != ".config/picom" and . != ".config/polybar")
' "$MANIFEST" >/dev/null || fail 'obsolete i3 desktop paths remain in dotfiles manifest'

grep -Eq '^[[:space:]]+eww[[:space:]]*$' "$PROFILE" ||
  fail 'NixOS i3 integration must install Eww'
! grep -Fqi 'i3blocks' "$PROFILE" "$I3_CONFIG" "$DOTFILES_MODULE" ||
  fail 'i3blocks integration remains'
! grep -Eqi 'bumblebee|i3status' "$PROFILE" || fail 'legacy status provider remains'

printf 'PASS: i3 uses the upstream Eww bar without native i3bar\n'
