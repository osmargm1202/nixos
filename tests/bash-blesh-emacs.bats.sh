#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BLERC="$ROOT/dotfiles/config/shared/.blerc"
WIDGETS="$ROOT/dotfiles/config/shared/.config/bash/fzf-widgets.bash"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

grep -Fqx 'bleopt default_keymap=emacs' "$BLERC" ||
  fail 'Blesh must default to the Emacs keymap'
! grep -Fq 'vi_nmap' "$BLERC" || fail 'Blesh must not configure Vi normal mode'
! grep -Fq 'vi_imap' "$BLERC" || fail 'Blesh must not configure Vi insert mode'
[[ "$(grep -Fc 'ble-bind -m emacs' "$WIDGETS")" -eq 5 ]] ||
  fail 'all FZF widgets must be bound in the Emacs keymap'
! grep -Fq 'ble-bind -m vi_' "$WIDGETS" ||
  fail 'FZF widgets must not retain Vi bindings'
bash -n "$WIDGETS"

printf 'PASS: Bash uses Blesh Emacs editing without Vi mode\n'
