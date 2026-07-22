#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"
POWER="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-powermenu"
LOCK="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-lock"
DOTFILES="$ROOT/nixos/common-dotfiles.nix"
PROFILE="$ROOT/nixos/profiles/i3.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[ -x "$LOCK" ] || fail 'i3-lock helper missing or not executable'
grep -Fq '".local/bin/i3-lock"' "$DOTFILES" || fail 'i3-lock not deployed'
grep -Eq '^[[:space:]]+imagemagick[[:space:]]*$' "$PROFILE" || fail 'ImageMagick conversion dependency missing'
grep -Fq -- '-blur 0x8' "$LOCK" || fail 'wallpaper preprocessing blur missing'
grep -Fq -- '--inside-color=2e3440aa' "$LOCK" || fail 'lock indicator is not translucent'
grep -Fq -- '--image="$lock_image"' "$LOCK" || fail 'lock does not use converted PNG wallpaper'
if grep -Fq -- '--blur=8' "$LOCK"; then fail 'i3lock blur cannot blur an opaque supplied image'; fi
grep -Fq -- '--clock' "$LOCK" || fail 'lock clock missing'

grep -Fq 'xss-lock --transfer-sleep-lock -- i3-lock --nofork' "$CONFIG" || fail 'idle lock bypasses themed helper'
grep -Fq 'bindsym $mod+Mod1+l exec --no-startup-id i3-lock' "$CONFIG" || fail 'Mod+Alt+L bypasses themed helper'
grep -Fq 'bindsym $mod+Shift+l exec --no-startup-id i3-lock' "$CONFIG" || fail 'legacy lock shortcut bypasses helper'
grep -Fq 'Lock) exec i3-lock' "$POWER" || fail 'power menu bypasses themed helper'

bash -n "$LOCK"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/state/i3" "$tmp/images" "$tmp/runtime"
image="$tmp/images/background.webp"
printf 'webp fixture\n' >"$image"
printf '%s\n' "$image" >"$tmp/state/i3/wallpaper"
cat >"$tmp/bin/magick" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$MAGICK_CALLS"
[[ "${MAGICK_FAIL:-0}" == 0 ]] || exit 7
output="${!#}"
printf 'converted png\n' >"$output"
STUB
cat >"$tmp/bin/xrandr" <<'STUB'
#!/usr/bin/env bash
printf 'Screen 0: minimum 320 x 200, current 1920 x 1080, maximum 16384 x 16384\n'
STUB
cat >"$tmp/bin/i3lock-color" <<'STUB'
#!/usr/bin/env bash
for arg in "$@"; do
  case "$arg" in --image=*) [[ -f "${arg#--image=}" ]] || exit 9 ;; esac
done
printf '%s\n' "$*" >"$LOCK_CALLS"
STUB
chmod +x "$tmp/bin/magick" "$tmp/bin/xrandr" "$tmp/bin/i3lock-color"
export LOCK_CALLS="$tmp/calls" MAGICK_CALLS="$tmp/magick-calls"
XDG_RUNTIME_DIR="$tmp/runtime" XDG_STATE_HOME="$tmp/state" PATH="$tmp/bin:$PATH" "$LOCK" --nofork
grep -Fq -- "$image" "$tmp/magick-calls" || fail 'persisted WebP was not converted'
grep -Fq -- '-blur 0x8' "$tmp/magick-calls" || fail 'ImageMagick blur was not applied'
grep -Eq -- '--image=.*\.png' "$tmp/calls" || fail 'converted PNG not passed to i3lock-color'
grep -Fq -- '--nofork' "$tmp/calls" || fail 'xss-lock foreground argument not preserved'
MAGICK_FAIL=1 XDG_RUNTIME_DIR="$tmp/runtime" XDG_STATE_HOME="$tmp/state" PATH="$tmp/bin:$PATH" "$LOCK"
grep -Fq -- '--color=2e3440ff' "$tmp/calls" || fail 'conversion failure did not fall back to secure color lock'

printf 'PASS: every lock path uses blurred persisted wallpaper and translucent styling\n'
