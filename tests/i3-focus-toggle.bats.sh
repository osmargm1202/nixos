#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"

grep -Fq 'bindsym Mod1+Escape focus last' "$CONFIG" || {
  printf '%s\n' 'FAIL: Alt+Escape must focus the previously focused window' >&2
  exit 1
}

printf '%s\n' 'PASS: Alt+Escape toggles the last focused i3 window'
