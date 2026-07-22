#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

grep -Fq 'bindsym $mod+g layout tabbed' "$CONFIG" || fail 'Mod+G grouped tabs binding missing'
grep -Fq 'bindsym $mod+Shift+g layout default' "$CONFIG" || fail 'Mod+Shift+G normal layout binding missing'

if grep -Eq '^bindsym \$mod\+(Ctrl\+|Shift\+|Mod1\+)?s([[:space:]]|$)' "$CONFIG"; then
  fail 'Mod+S family must not manage scratchpads or stacking'
fi
if grep -Eq 'scratchpad|layout stacking' "$CONFIG"; then
  fail 'i3 must expose only grouped tabs and normal split layout'
fi

printf 'PASS: i3 uses Mod+G grouped tabs and Mod+Shift+G normal layout\n'
