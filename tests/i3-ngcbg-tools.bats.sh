#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT/nixos/profiles/i3.nix"
CONFIG="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"
SWALLOW="$ROOT/dotfiles/config/profiles/i3/.config/i3/swallow.conf"
XLOGOUT="$ROOT/dotfiles/config/profiles/i3/.config/xlogout/xlogout.conf"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

grep -Fq 'ngcbgI3Tools = pkgs.callPackage ../packages/ngcbg-i3-tools.nix { };' "$PROFILE" || fail 'ngcbg i3 tools package set is not imported'
for package in autotiling rootbtnd i3swallow xlogout; do
  grep -Eq "^[[:space:]]+ngcbgI3Tools\\.${package}[[:space:]]*$" "$PROFILE" || fail "ngcbg ${package} package missing from i3 profile"
done

grep -Fq 'exec_always --no-startup-id autotiling' "$CONFIG" || fail 'autotiling daemon missing'
grep -Fq "exec_always --no-startup-id rootbtnd -r -b button1:'i3-rofi --drun' -b button3:i3-main-menu" "$CONFIG" || fail 'rootbtnd root-button actions missing'
grep -Fq 'exec --no-startup-id i3swallowd' "$CONFIG" || fail 'i3swallow daemon missing'

expected_swallow_rules=(
  discord
  Steam
  Zutty
  kitty
)
mapfile -t actual_swallow_rules < <(sed '/^[[:space:]]*$/d; /^[[:space:]]*#/d' "$SWALLOW")
[ "${#actual_swallow_rules[@]}" -eq "${#expected_swallow_rules[@]}" ] || fail 'swallow allow-list must contain exactly four rules'
for index in "${!expected_swallow_rules[@]}"; do
  [ "${actual_swallow_rules[$index]}" = "${expected_swallow_rules[$index]}" ] || fail "swallow rule $((index + 1)) must be ${expected_swallow_rules[$index]}"
done
! grep -Fqi 'xrandr' "$SWALLOW" || fail 'xrandr must not be in swallow allow-list'

grep -Fq '[font]' "$XLOGOUT" || fail 'xlogout font configuration missing'
grep -Eq '^icon_font = .*Nerd Font' "$XLOGOUT" || fail 'xlogout must use a Nerd-font-capable icon font'
for button_command in \
  'button.logout:command = i3-msg exit' \
  'button.suspend:command = systemctl suspend' \
  'button.reboot:command = systemctl reboot' \
  'button.shutdown:command = systemctl poweroff'; do
  button="${button_command%%:*}"
  command="${button_command#*:}"
  grep -Fq "[$button]" "$XLOGOUT" || fail "xlogout $button missing"
  grep -Fq "$command" "$XLOGOUT" || fail "xlogout $button action missing"
done
for key in e s r p; do
  grep -Fq "key = $key" "$XLOGOUT" || fail "xlogout keyboard action $key missing"
done

workspace_move_bindings=(
  'bindsym $mod+Shift+1 move container to workspace number $ws1; workspace number $ws1'
  'bindsym $mod+Shift+2 move container to workspace number $ws2; workspace number $ws2'
  'bindsym $mod+Shift+3 move container to workspace number $ws3; workspace number $ws3'
  'bindsym $mod+Shift+4 move container to workspace number $ws4; workspace number $ws4'
  'bindsym $mod+Shift+5 move container to workspace number $ws5; workspace number $ws5'
  'bindsym $mod+Shift+6 move container to workspace number $ws6; workspace number $ws6'
  'bindsym $mod+Shift+7 move container to workspace number $ws7; workspace number $ws7'
  'bindsym $mod+Shift+8 move container to workspace number $ws8; workspace number $ws8'
  'bindsym $mod+Shift+9 move container to workspace number $ws9; workspace number $ws9'
  'bindsym $mod+Shift+0 move container to workspace number $ws10; workspace number $ws10'
  'bindsym $mod+Ctrl+Home move container to workspace number $ws1; workspace number $ws1'
  'bindsym $mod+Ctrl+End move container to workspace number $ws10; workspace number $ws10'
  'bindsym $mod+Ctrl+Page_Down move container to workspace prev; workspace prev'
  'bindsym $mod+Ctrl+Page_Up move container to workspace next; workspace next'
  'bindsym $mod+Ctrl+u move container to workspace prev; workspace prev'
  'bindsym $mod+Ctrl+i move container to workspace next; workspace next'
)
for binding in "${workspace_move_bindings[@]}"; do
  grep -Fq "$binding" "$CONFIG" || fail "workspace move-and-follow binding missing: $binding"
done

printf 'PASS: i3 config deploys ngcbg tools, safe xlogout actions, swallow rules, and workspace move-follow bindings\n'
