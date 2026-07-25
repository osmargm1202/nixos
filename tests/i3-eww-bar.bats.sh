#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT/nixos/profiles/i3.nix"
I3="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"
DOTFILES="$ROOT/nixos/common-dotfiles.nix"
BLOCKS="$ROOT/dotfiles/config/profiles/i3/.config/i3blocks"
STATUS_HELPER="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3blocks-status"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[[ ! -e "$BLOCKS" ]] || fail 'i3blocks config remains in the i3 profile'
[[ ! -e "$STATUS_HELPER" ]] || fail 'i3blocks dispatcher remains in the i3 profile'
! grep -Fqi 'i3blocks' "$PROFILE" "$I3" "$DOTFILES" ||
  fail 'i3blocks is still installed, launched, or deployed'

for service in eww-widgets-sync eww-widgets-bar; do
  grep -Fq "systemd.user.services.$service" "$PROFILE" || fail "$service service missing"
done
grep -Fq 'https://github.com/Saimoomedits/eww-widgets.git' "$PROFILE" ||
  fail 'Eww source is not the requested upstream repository'
grep -Fq 'git clone --depth 1 --branch main' "$PROFILE" ||
  fail 'upstream Eww repository is not cloned directly'
grep -Fq 'if ! git -C "$upstream" fetch --depth 1 origin main; then' "$PROFILE" ||
  fail 'existing upstream checkout cannot tolerate an offline login'
grep -Fq 'warning: unable to refresh Eww widgets; using the existing checkout' "$PROFILE" ||
  fail 'offline upstream refresh does not retain the existing checkout'
grep -Fq 'ln -sfn upstream/eww/bar "$bar_dir"' "$PROFILE" ||
  fail 'upstream bar is not exposed as the Eww config directory'
grep -Fq 'ln -sfn "${lib.getExe pkgs.eww}" "$HOME/.local/bin/eww/eww"' "$PROFILE" ||
  fail 'upstream Eww command compatibility path missing'
grep -Eq '^[[:space:]]+eww[[:space:]]*$' "$PROFILE" || fail 'Eww package missing'
grep -Eq '^[[:space:]]+alsa-utils[[:space:]]*$' "$PROFILE" ||
  fail 'alsa-utils is required by the upstream volume widget'
grep -Fq 'eww --config "$HOME/.config/eww/bar" daemon' "$PROFILE" ||
  fail 'Eww daemon does not use the upstream bar config'
grep -Fq 'eww --config "$HOME/.config/eww/bar" open bar' "$PROFILE" ||
  fail 'Eww bar window is not opened'
grep -Fq "exec --no-startup-id sh -c 'dbus-update-activation-environment --systemd DISPLAY XAUTHORITY && systemctl --user start eww-widgets-bar.service'" "$I3" ||
  fail 'i3 does not export X11 variables before starting Eww'

printf 'PASS: i3 starts Saimoomedits Eww bar directly and removes i3blocks\n'
