#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"
POWER="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-powermenu"
LOCK="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-lock"
WALLPAPER="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-wallpaper"
ASSETS="$ROOT/dotfiles/config/profiles/i3/.local/share/i3-lock-backgrounds"
DOTFILES="$ROOT/nixos/common-dotfiles.nix"
PROFILE="$ROOT/nixos/profiles/i3.nix"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

[[ -x "$LOCK" ]] || fail 'i3-lock helper missing or not executable'
grep -Fq '".local/share/i3-lock-backgrounds"' "$DOTFILES" || fail 'lock backgrounds are not deployed'
grep -Eq '^[[:space:]]+i3lock-color[[:space:]]*$' "$PROFILE" || fail 'i3lock-color package missing'
grep -Eq '^[[:space:]]+librsvg[[:space:]]*$' "$PROFILE" || fail 'librsvg package missing'
grep -Fq '"image/svg+xml" = [ "org.gnome.Loupe.desktop" ];' "$PROFILE" ||
  fail 'Loupe must open SVG images by default'
for background in "$ASSETS"/*.svg; do [[ -s "$background" ]] || fail 'missing SVG lock background'; done
grep -Fq -- '--bar-indicator' "$LOCK" || fail 'lock must use rectangular bar indicator'
installed_i3lock="$(readlink -f "$(command -v i3lock-color)")"
zcat "$(dirname "$(dirname "$installed_i3lock")")/share/man/man1/i3lock-color.1.gz" |
  grep -Fq '\-\-bar\-indicator' || fail 'installed i3lock-color lacks bar indicator support'
grep -Fq 'rsvg-convert --width "$width" --height "$height"' "$LOCK" || fail 'lock background must render at active resolution'
! grep -Fq 'lock_background_bin=' "$WALLPAPER" || fail 'wallpaper must not generate lock screenshots'
grep -Fq 'xss-lock --transfer-sleep-lock -- $run i3-lock -n' "$CONFIG" || fail 'idle lock bypasses helper'
grep -Fq 'Lock) exec i3-lock' "$POWER" || fail 'power menu bypasses helper'
bash -n "$LOCK" "$WALLPAPER"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT; mkdir -p "$tmp/bin" "$tmp/assets"
printf '<svg/>' >"$tmp/assets/test.svg"
cat >"$tmp/bin/i3lock-color" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$LOCK_CALLS"
EOF
cat >"$tmp/bin/xrandr" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' 'Screen 0: minimum 8 x 8, current 2560 x 1600, maximum 32767 x 32767'
EOF
cat >"$tmp/bin/rsvg-convert" <<'EOF'
#!/usr/bin/env bash
printf png
EOF
chmod +x "$tmp/bin/"*
export LOCK_CALLS="$tmp/calls"
I3_LOCK_BACKGROUNDS_DIR="$tmp/assets" XDG_RUNTIME_DIR="$tmp" PATH="$tmp/bin:$PATH" "$LOCK" -n
grep -Fxq -- '--bar-indicator' "$tmp/calls" || fail 'bar indicator option missing'
grep -Eq '^--image=.*/background\.[[:alnum:]]+\.png$' "$tmp/calls" || fail 'rendered background missing'
grep -Fxq -- '-e' "$tmp/calls" || fail 'empty-password safeguard missing'
grep -Fxq -- '-n' "$tmp/calls" || fail 'xss-lock foreground argument not preserved'
rendered_path="$(sed -n 's/^--image=//p' "$tmp/calls")"
[[ ! -e "$rendered_path" ]] || fail 'temporary rendered background was not removed'
printf 'PASS: i3 lock renders a random resolution-matched SVG background\n'
