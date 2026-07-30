#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"
POWER="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-powermenu"
LOCK="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-lock"
LOCK_BACKGROUND="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-lock-background"
WALLPAPER="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-wallpaper"
DOTFILES="$ROOT/nixos/common-dotfiles.nix"
PROFILE="$ROOT/nixos/profiles/i3.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[[ -x "$LOCK" ]] || fail 'i3-lock helper missing or not executable'
[[ -x "$LOCK_BACKGROUND" ]] || fail 'i3-lock-background helper missing or not executable'
grep -Fq '".local/bin/i3-lock"' "$DOTFILES" || fail 'i3-lock not deployed'
grep -Fq '".local/bin/i3-lock-background"' "$DOTFILES" || fail 'i3-lock-background not deployed'
grep -Eq '^[[:space:]]+i3lock-color[[:space:]]*$' "$PROFILE" || fail 'i3lock-color package missing'
grep -Eq '^[[:space:]]+ffmpeg[[:space:]]*$' "$PROFILE" || fail 'ffmpeg package missing'
if grep -Eq 'i3lock-fancy|screenshotCommand' "$PROFILE"; then
  fail 'ImageMagick-based i3lock-fancy remains installed'
fi
grep -Fq 'lock_background_bin=' "$WALLPAPER" || fail 'wallpaper does not locate lock background helper'
grep -Fq 'update_lock_background ||' "$WALLPAPER" || fail 'wallpaper does not refresh lock background after applying'
grep -Fq 'i3lock-color -i "$lock_image" -e "$@"' "$LOCK" || fail 'lock helper does not use saved PNG'
grep -Fq 'exec i3lock-color -c 2e3440 -e "$@"' "$LOCK" || fail 'lock helper has no solid-color fallback'
if grep -Eq 'i3lock-fancy|scrot|magick|--image|--color|--ignore-empty-password' "$LOCK"; then
  fail 'ImageMagick screenshot lock remains active'
fi

grep -Fq 'xss-lock --transfer-sleep-lock -- $run i3-lock -n' "$CONFIG" || fail 'idle lock bypasses PATH-safe helper'
grep -Fq 'bindsym $mod+Mod1+l exec --no-startup-id $run i3-lock' "$CONFIG" || fail 'Mod+Alt+L bypasses helper'
grep -Fq 'bindsym $mod+Shift+l exec --no-startup-id $run i3-lock' "$CONFIG" || fail 'legacy lock shortcut bypasses helper'
grep -Fq 'Lock) exec i3-lock' "$POWER" || fail 'power menu bypasses helper'

bash -n "$LOCK" "$LOCK_BACKGROUND" "$WALLPAPER"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/state"
cat >"$tmp/bin/i3lock-color" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$LOCK_CALLS"
STUB

cat >"$tmp/bin/ffmpeg" <<'STUB'
#!/usr/bin/env bash
input=''
previous=''
for argument in "$@"; do
  [[ "$previous" == -i ]] && input="$argument"
  previous="$argument"
done
cp -- "$input" "${!#}"
STUB
chmod +x "$tmp/bin/i3lock-color" "$tmp/bin/ffmpeg"
source_image="$tmp/current wallpaper.png"
printf 'saved wallpaper\n' >"$source_image"
lock_image="$tmp/state/i3/lock_screen.png"
PATH="$tmp/bin:$PATH" XDG_STATE_HOME="$tmp/state" "$LOCK_BACKGROUND" "$source_image"
cmp -s "$source_image" "$lock_image" || fail 'lock image was not saved atomically'

export LOCK_CALLS="$tmp/calls"
XDG_STATE_HOME="$tmp/state" PATH="$tmp/bin:$PATH" "$LOCK" -n
grep -Fxq -- '-i' "$tmp/calls" || fail 'saved lock image option missing'
grep -Fxq -- "$lock_image" "$tmp/calls" || fail 'saved lock image not passed to i3lock-color'
grep -Fxq -- '-e' "$tmp/calls" || fail 'empty-password safeguard missing'
grep -Fxq -- '-n' "$tmp/calls" || fail 'xss-lock foreground argument not preserved'
[[ ! -e "$tmp/fallback-calls" ]] || fail 'unexpected fallback state'

XDG_STATE_HOME="$tmp/state" "$LOCK_BACKGROUND" --clear
[[ ! -e "$tmp/state/i3/lock_screen" ]] || fail 'lock pointer was not cleared'
XDG_STATE_HOME="$tmp/state" PATH="$tmp/bin:$PATH" "$LOCK" -n
grep -Fxq -- '-c' "$tmp/calls" || fail 'solid-color fallback option missing'
grep -Fxq -- '2e3440' "$tmp/calls" || fail 'solid-color fallback missing'
grep -Fxq -- '-n' "$tmp/calls" || fail 'fallback did not remain foregrounded for xss-lock'

printf 'PASS: every lock path uses a pre-generated background without ImageMagick\n'
