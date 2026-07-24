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

grep -Fq 'bindsym $mod+s scratchpad show' "$CONFIG" || fail 'Mod+S scratchpad toggle binding missing'

printf 'PASS: i3 uses grouped tabs, normal split layout, and Mod+S scratchpad toggle\n'
