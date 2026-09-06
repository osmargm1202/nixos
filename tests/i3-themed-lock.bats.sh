#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"
POWER="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-powermenu"
LOCK="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-lock"
WALLPAPER="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-wallpaper"
PROFILE="$ROOT/nixos/profiles/i3.nix"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

[[ -x "$LOCK" ]] || fail 'i3-lock helper missing or not executable'
grep -Eq '^[[:space:]]+i3lock-color[[:space:]]*$' "$PROFILE" || fail 'i3lock-color package missing'
! grep -Fq 'librsvg' "$PROFILE" || fail 'native lock theme must not require SVG rendering'
! grep -Eq '(rsvg-convert|convert|magick|--image=)' "$LOCK" ||
  fail 'native lock theme must not render or process images'
for option in --clock --force-clock --indicator --time-size=72 \
  --time-pos=x+w/2:y+h/2-180 --ind-pos=x+w/2:y+h/2+70 \
  --inside-color=172554ff --ring-color=60a5faff \
  --keyhl-color=7dd3fcff --bshl-color=fda4afff --no-modkey-text; do
  grep -Fq -- "$option" "$LOCK" || fail "lock option missing: $option"
done
! grep -Fq -- '--bar-indicator' "$LOCK" ||
  fail 'simple lock theme must not use the bar indicator'
! grep -Fq -- '--greeter-text' "$LOCK" ||
  fail 'lock must reserve the upper center for the clock'
! grep -Fq 'lock_background_bin=' "$WALLPAPER" || fail 'wallpaper must not generate lock screenshots'
grep -Fq 'xss-lock --transfer-sleep-lock -- $run i3-lock -n' "$CONFIG" || fail 'idle lock bypasses helper'
grep -Fq 'Lock) exec i3-lock' "$POWER" || fail 'power menu bypasses helper'
bash -n "$LOCK" "$WALLPAPER"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT; mkdir -p "$tmp/bin"
cat >"$tmp/bin/i3lock-color" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$LOCK_CALLS"
EOF
chmod +x "$tmp/bin/i3lock-color"
export LOCK_CALLS="$tmp/calls"
PATH="$tmp/bin:$PATH" "$LOCK" -n
for option in --color=0f172aff --clock --force-clock --indicator --time-size=72 \
  --time-pos=x+w/2:y+h/2-180 --ind-pos=x+w/2:y+h/2+70 \
  --inside-color=172554ff --ring-color=60a5faff \
  --keyhl-color=7dd3fcff --bshl-color=fda4afff --no-modkey-text -e -n; do
  grep -Fxq -- "$option" "$tmp/calls" || fail "native lock call missing: $option"
done
printf '%s\n' 'PASS: i3 lock uses a simple native circular indicator'
