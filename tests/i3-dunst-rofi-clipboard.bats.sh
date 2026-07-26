#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DUNST="$ROOT/dotfiles/config/profiles/i3/.config/dunst/dunstrc"
CLIPBOARD="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-clipboard"
CLIPCAT_CONFIG="$ROOT/dotfiles/config/shared/.config/clipcat/clipcatd.toml"
CLIPCAT_MENU="$ROOT/dotfiles/config/shared/.config/clipcat/clipcat-menu.toml"
PROFILE="$ROOT/nixos/profiles/i3.nix"
CONFIG="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"
MENU="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-main-menu"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

! grep -Fq 'i3-gh0stzk' "$DUNST" || fail 'Dunst keeps a removed Polybar rice dependency'
grep -Eq '^exec[[:space:]]+--no-startup-id[[:space:]]+dunst$' "$CONFIG" ||
  fail 'i3 must start Dunst directly'
grep -Fq 'clipcat' "$PROFILE" || fail 'Clipcat package/service missing'
grep -Fq 'systemd.user.services.i3-clipcat' "$PROFILE" || fail 'Clipcat user service missing'
grep -Fq -- '--no-daemon' "$PROFILE" || fail 'Clipcat must remain supervised by systemd'
grep -Fq -- '--grpc-socket-path %t/clipcat/grpc.sock' "$PROFILE" || fail 'Clipcat socket must use the current runtime directory'
! grep -Eq '/run/user/[0-9]+|/tmp/clipcatd-history' "$CLIPCAT_CONFIG" || fail 'Clipcat daemon keeps a fixed runtime path'
grep -Fq '@RUNTIME_SOCKET@' "$CLIPCAT_MENU" || fail 'Clipcat menu is not a runtime socket template'
grep -Fq 'XDG_RUNTIME_DIR' "$CLIPBOARD" || fail 'clipboard helper does not resolve the active runtime directory'
grep -Fq 'clipcat-menu --config' "$CLIPBOARD" || fail 'clipboard helper does not execute Clipcat'
grep -Fq 'i3-clipcat.service' "$CLIPBOARD" || fail 'clipboard helper does not start Clipcat when needed'
grep -Fq 'bindsym $mod+v exec --no-startup-id $run i3-clipboard' "$CONFIG" || fail 'Mod+V does not open Rofi clipboard'
grep -Fq 'Clipboard) exec i3-clipboard' "$MENU" || fail 'main menu does not open Rofi clipboard'
bash -n "$CLIPBOARD"

printf 'PASS: i3 starts Dunst directly and clipboard uses UID-independent Clipcat\n'
