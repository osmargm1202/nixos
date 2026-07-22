#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"
BIN="$ROOT/dotfiles/config/profiles/i3/.local/bin"
DOTFILES="$ROOT/nixos/common-dotfiles.nix"
PROFILE="$ROOT/nixos/profiles/i3.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

required_bindings=(
  'bindsym $mod+w exec --no-startup-id i3-zen-new-window'
  'bindsym $mod+Tab exec --no-startup-id i3-rofi --window'
  'bindsym $mod+Shift+w exec --no-startup-id chromium'
  'bindsym $mod+o exec --no-startup-id i3-obsidian-open-or-focus'
  'bindsym $mod+Shift+p exec --no-startup-id i3-pi-prompt'
  'bindsym $mod+Shift+Return exec --no-startup-id $term'
  'bindsym $mod+F10 exec --no-startup-id pavucontrol'
  'bindsym $mod+Mod1+e exec --no-startup-id i3-powermenu'
  'bindsym $mod+Mod1+l exec --no-startup-id i3-lock'
  'bindsym $mod+Mod1+w exec --no-startup-id i3-wallpaper --random'
  'bindsym $mod+Ctrl+Shift+m exec --no-startup-id dunstctl close-all'
  'bindsym Ctrl+XF86AudioRaiseVolume exec --no-startup-id mic-volume-osd up'
  'bindsym Ctrl+XF86AudioLowerVolume exec --no-startup-id mic-volume-osd down'
  'bindsym XF86MonBrightnessUp exec --no-startup-id brightness-osd up'
  'bindsym XF86MonBrightnessDown exec --no-startup-id brightness-osd down'
  'bindsym Ctrl+Mod1+Delete exec --no-startup-id i3-msg exit'
  'bindsym $mod+Ctrl+c move position center'
  'bindsym $mod+r layout toggle split'
  'bindsym $mod+Ctrl+Mod1+r mode "resize"'
  'bindsym $mod+Ctrl+Left move left'
  'bindsym $mod+Ctrl+Right move right'
  'bindsym $mod+Home workspace number $ws1'
  'bindsym $mod+End workspace number $ws10'
  'bindsym $mod+Page_Down workspace prev'
  'bindsym $mod+Page_Up workspace next'
)
for binding in "${required_bindings[@]}"; do
  grep -Fq "$binding" "$CONFIG" || fail "missing parity binding: $binding"
done

for helper in i3-zen-new-window i3-obsidian-open-or-focus i3-pi-prompt; do
  [ -x "$BIN/$helper" ] || fail "$helper missing or not executable"
  grep -Fq "\".local/bin/$helper\"" "$DOTFILES" || fail "$helper not deployed"
  bash -n "$BIN/$helper"
done

grep -Fq 'xkb-switch' "$PROFILE" || fail 'xkb-switch package missing'
grep -Fq 'exec xkb-switch -n' "$BIN/i3-keyboard-menu" || fail 'keyboard Toggle must use active XKB group'
grep -Fq '/^[[:space:]]*bindsym /' "$BIN/i3-hotkeys" || fail 'hotkey help must include indented mode bindings'
grep -Fq '"$selection" =~ ^\[([^]]+)\]:([0-9]+)$' "$BIN/i3-ssh-host" || fail 'SSH helper must parse bracketed known-host ports'

printf 'PASS: i3 restores active daily Hyprland shortcut and helper parity\n'
