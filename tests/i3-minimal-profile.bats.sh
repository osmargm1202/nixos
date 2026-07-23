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

grep -Fq 'bar {' "$I3_CONFIG" || fail 'native i3bar block missing'
grep -Fxq '  status_command /run/current-system/sw/bin/i3blocks -c "$HOME/.config/i3blocks/config"' "$I3_CONFIG" ||
	fail 'i3bar must run the portable i3blocks config'
grep -Fq 'tray_output primary' "$I3_CONFIG" || fail 'i3bar must own the primary tray'
grep -Fq 'exec --no-startup-id nm-applet' "$I3_CONFIG" || fail 'NetworkManager applet missing'
grep -Fq 'exec --no-startup-id blueman-applet' "$I3_CONFIG" || fail 'Bluetooth applet missing'
grep -Fq 'exec --no-startup-id udiskie --tray' "$I3_CONFIG" || fail 'removable-disk applet missing'

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

grep -Fq 'extraPackages = [ pkgs.i3blocks ];' "$PROFILE" ||
	fail 'NixOS i3 integration must install i3blocks'
! grep -Eqi 'bumblebee|i3status' "$PROFILE" || fail 'legacy status provider remains'

printf 'PASS: i3 uses native i3bar with i3blocks and no custom panel\n'
