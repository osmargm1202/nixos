#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DUNST="$ROOT/dotfiles/config/profiles/i3/.config/dunst/dunstrc"
CLIPBOARD="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-clipboard"
CONFIG="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"
MENU="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-main-menu"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

mapfile -t timeouts < <(grep -E '^[[:space:]]*timeout[[:space:]]*=' "$DUNST")
[[ "${#timeouts[@]}" -eq 3 ]] || fail 'Dunst must define one timeout for each urgency'
for timeout in "${timeouts[@]}"; do
  [[ "$timeout" =~ =[[:space:]]*8$ ]] || fail "Dunst notification is not limited to 8 seconds: $timeout"
done
if grep -Eq 'timeout[[:space:]]*=[[:space:]]*0' "$DUNST"; then
  fail 'permanent Dunst notification remains'
fi

grep -Fq 'export CM_LAUNCHER=rofi' "$CLIPBOARD" || fail 'clipmenu launcher is not Rofi'
grep -Fq 'exec clipmenu -i -p Clipboard' "$CLIPBOARD" || fail 'clipboard helper does not execute clipmenu'
grep -Fq 'bindsym $mod+v exec --no-startup-id i3-clipboard' "$CONFIG" || fail 'Mod+V does not open Rofi clipboard'
grep -Fq 'Clipboard) exec i3-clipboard' "$MENU" || fail 'main menu does not open Rofi clipboard'
bash -n "$CLIPBOARD"

printf 'PASS: Dunst expires at 8 seconds and clipboard always uses Rofi\n'
