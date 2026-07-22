#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-wallpaper"
PROFILE="$ROOT/nixos/profiles/i3.nix"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[[ -x "$HELPER" ]] || fail 'i3-wallpaper helper missing'
grep -Eq '^[[:space:]]+xdotool[[:space:]]*$' "$PROFILE" || fail 'active-monitor detection lacks xdotool'
bash -n "$HELPER"

mkdir -p "$TMP/bin" "$TMP/home" "$TMP/state" "$TMP/wallpapers"
cat >"$TMP/bin/xrandr" <<'STUB'
#!/usr/bin/env bash
mode="${MONITOR_MODE:-default}"
case "${1:-}:$mode" in
  --listactivemonitors:laptop)
    printf 'Monitors: 1\n 0: +*eDP-1 1920/309x1080/174+0+0 eDP-1\n'
    ;;
  --listactivemonitors:reverse|--listactivemonitors:no-primary)
    printf 'Monitors: 2\n 0: +HDMI-1 1920/509x1080/286+1920+0 HDMI-1\n 1: +eDP-1 1920/309x1080/174+0+0 eDP-1\n'
    ;;
  --listactivemonitors:*)
    printf 'Monitors: 2\n 0: +*eDP-1 1920/309x1080/174+0+0 eDP-1\n 1: +HDMI-1 1920/509x1080/286+1920+0 HDMI-1\n'
    ;;
  --query:laptop)
    printf 'eDP-1 connected primary 1920x1080+0+0\n'
    ;;
  --query:negative)
    printf 'eDP-1 connected 1920x1080-1920+0\nHDMI-1 connected primary 1920x1080+0+0\n'
    ;;
  --query:no-primary)
    printf 'eDP-1 connected 1920x1080+0+0\nHDMI-1 connected 1920x1080+1920+0\n'
    ;;
  --query:*)
    printf 'eDP-1 connected primary 1920x1080+0+0\nHDMI-1 connected 1920x1080+1920+0\n'
    ;;
  *) exit 2 ;;
esac
STUB
cat >"$TMP/bin/xdotool" <<'STUB'
#!/usr/bin/env bash
if [[ "${1:-}" == getmouselocation ]]; then
  [[ "${POINTER_FAIL:-0}" != 1 ]] || exit 1
  printf 'X=%s\nY=%s\nSCREEN=0\nWINDOW=1\n' "${POINTER_X:-100}" "${POINTER_Y:-100}"
elif [[ "${1:-}" == getactivewindow ]]; then
  printf 'WINDOW=2\nX=%s\nY=%s\nWIDTH=%s\nHEIGHT=%s\nSCREEN=0\n' \
    "${FOCUS_X:-0}" "${FOCUS_Y:-0}" "${FOCUS_WIDTH:-800}" "${FOCUS_HEIGHT:-600}"
else
  exit 2
fi
STUB
cat >"$TMP/bin/feh" <<'STUB'
#!/usr/bin/env bash
[[ "${FEH_FAIL:-0}" != 1 ]] || exit 1
printf 'feh' >>"$CALLS"
printf ' <%s>' "$@" >>"$CALLS"
printf '\n' >>"$CALLS"
STUB
cat >"$TMP/bin/notify-send" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${NOTIFY_CALLS:-/dev/null}"
STUB
cat >"$TMP/bin/shuf" <<'STUB'
#!/usr/bin/env bash
if [[ -n "${SHUF_VALUE:-}" ]]; then
  printf '%s\n' "$SHUF_VALUE"
else
  head -n1
fi
STUB
chmod +x "$TMP/bin/"*

laptop="$TMP/wallpapers/laptop image.jpg"
external="$TMP/wallpapers/external image.png"
shared="$TMP/wallpapers/shared image.webp"
focus="$TMP/wallpapers/focus image.jpg"
printf 'image\n' >"$laptop"
printf 'image\n' >"$external"
printf 'image\n' >"$shared"
printf 'image\n' >"$focus"

run_wallpaper() {
  CALLS="$TMP/calls" HOME="$TMP/home" XDG_STATE_HOME="$TMP/state" \
    I3_WALLPAPER_DIR="$TMP/wallpapers" PATH="$TMP/bin:$PATH" "$HELPER" "$@"
}

# Same-image mode remains available and seeds the legacy/default state.
: >"$TMP/calls"
run_wallpaper --set "$shared"
grep -Fxq "feh <--bg-fill> <$shared> <$shared>" "$TMP/calls" ||
  fail '--set must apply the same wallpaper to every active output'
[[ "$(cat "$TMP/state/i3/wallpaper")" == "$shared" ]] || fail 'shared fallback state missing'
[[ -L "$TMP/state/i3/wallpapers" ]] || fail 'shared state is not an atomic generation pointer'
[[ "$(cat "$TMP/state/i3/wallpapers/.default")" == "$shared" ]] || fail 'generation default missing'
[[ ! -e "$TMP/state/i3/wallpapers/eDP-1" ]] || fail 'shared mode did not clear output override'
grep -Fq 'exec {wallpaper_lock_fd}<"$state_dir"' "$HELPER" ||
  fail 'wallpaper lock does not use non-truncating directory descriptor'
grep -Fq 'flock -x "$wallpaper_lock_fd"' "$HELPER" || fail 'wallpaper transactions are not serialized'
valuable="$TMP/valuable-state"
printf 'valuable-data\n' >"$valuable"
ln -s "$valuable" "$TMP/state/i3/wallpaper.lock"
if run_wallpaper --invalid >/dev/null 2>&1; then fail 'invalid mode unexpectedly succeeded'; fi
[[ "$(cat "$valuable")" == valuable-data ]] || fail 'stale lock symlink target was truncated'

# Pointer is on HDMI-1: only that output changes; eDP-1 keeps shared wallpaper.
: >"$TMP/calls"
POINTER_X=2200 POINTER_Y=300 run_wallpaper --set-active "$external"
grep -Fxq "feh <--bg-fill> <$shared> <$external>" "$TMP/calls" ||
  fail 'pointer monitor did not receive selected wallpaper'
[[ "$(cat "$TMP/state/i3/wallpapers/HDMI-1")" == "$external" ]] ||
  fail 'HDMI-1 wallpaper state missing'

# Restore reconstructs complete Feh order from output identities.
: >"$TMP/calls"
run_wallpaper --restore
grep -Fxq "feh <--bg-fill> <$shared> <$external>" "$TMP/calls" ||
  fail 'per-output wallpaper restore lost monitor mapping'

# If pointer lookup fails, focused-window center selects eDP-1.
: >"$TMP/calls"
POINTER_FAIL=1 FOCUS_X=100 FOCUS_Y=100 FOCUS_WIDTH=900 FOCUS_HEIGHT=700 \
  run_wallpaper --set-active "$focus"
grep -Fxq "feh <--bg-fill> <$focus> <$external>" "$TMP/calls" ||
  fail 'focused-window monitor fallback did not select eDP-1'
[[ "$(cat "$TMP/state/i3/wallpapers/eDP-1")" == "$focus" ]] ||
  fail 'eDP-1 wallpaper state missing'

# Explicit output targeting supports scripts and monitor-profile integrations.
: >"$TMP/calls"
run_wallpaper --set-output HDMI-1 "$laptop"
grep -Fxq "feh <--bg-fill> <$focus> <$laptop>" "$TMP/calls" ||
  fail 'explicit output targeting changed wrong monitor'

# Failed visual application leaves the atomic state generation untouched.
generation_before="$(readlink "$TMP/state/i3/wallpapers")"
hdmi_before="$(cat "$TMP/state/i3/wallpapers/HDMI-1")"
if FEH_FAIL=1 run_wallpaper --set-output HDMI-1 "$external"; then
  fail 'failed Feh application unexpectedly committed state'
fi
[[ "$(readlink "$TMP/state/i3/wallpapers")" == "$generation_before" ]] ||
  fail 'failed Feh application changed generation pointer'
[[ "$(cat "$TMP/state/i3/wallpapers/HDMI-1")" == "$hdmi_before" ]] ||
  fail 'failed Feh application changed HDMI state'

# Feh ordering follows --listactivemonitors, not xrandr --query line order.
: >"$TMP/calls"
MONITOR_MODE=reverse run_wallpaper --restore
grep -Fxq "feh <--bg-fill> <$laptop> <$focus>" "$TMP/calls" ||
  fail 'Feh image order does not follow active-monitor indices'

# A disconnected output keeps its connector assignment and regains it later.
: >"$TMP/calls"
MONITOR_MODE=laptop run_wallpaper --restore
grep -Fxq "feh <--bg-fill> <$focus>" "$TMP/calls" || fail 'single-output restore failed'
[[ "$(cat "$TMP/state/i3/wallpapers/HDMI-1")" == "$laptop" ]] ||
  fail 'disconnected HDMI assignment was discarded'
: >"$TMP/calls"
run_wallpaper --restore
grep -Fxq "feh <--bg-fill> <$focus> <$laptop>" "$TMP/calls" ||
  fail 'reconnected HDMI assignment was not restored'

# Negative monitor geometry is valid and pointer targeting still wins.
: >"$TMP/calls"
MONITOR_MODE=negative POINTER_X=-200 POINTER_Y=200 run_wallpaper --set-active "$laptop"
grep -Fxq "feh <--bg-fill> <$laptop> <$laptop>" "$TMP/calls" ||
  fail 'negative-coordinate output was not targeted'

# Out-of-bounds pointer and focus fall back to primary, then first active output.
: >"$TMP/calls"
POINTER_FAIL=1 FOCUS_X=5000 FOCUS_Y=5000 run_wallpaper --set-active "$focus"
grep -Fxq "feh <--bg-fill> <$focus> <$laptop>" "$TMP/calls" || fail 'primary fallback failed'
: >"$TMP/calls"
MONITOR_MODE=no-primary POINTER_FAIL=1 FOCUS_X=5000 FOCUS_Y=5000 \
  run_wallpaper --set-active "$external"
grep -Fxq "feh <--bg-fill> <$external> <$focus>" "$TMP/calls" || fail 'first-output fallback failed'

# Random modes support one active output or one shared image for all.
: >"$TMP/calls"
POINTER_X=2200 POINTER_Y=200 SHUF_VALUE="$shared" run_wallpaper --random-active
grep -Fxq "feh <--bg-fill> <$focus> <$shared>" "$TMP/calls" || fail '--random-active changed wrong output'
: >"$TMP/calls"
SHUF_VALUE="$laptop" run_wallpaper --random
grep -Fxq "feh <--bg-fill> <$laptop> <$laptop>" "$TMP/calls" || fail '--random did not set all outputs'
[[ "$(cat "$TMP/state/i3/wallpapers/.default")" == "$laptop" ]] || fail 'random shared default missing'
[[ ! -e "$TMP/state/i3/wallpapers/eDP-1" ]] || fail 'shared random retained output override'

# Unsafe or inactive connector names are rejected before state mutation.
generation_before="$(readlink "$TMP/state/i3/wallpapers")"
if run_wallpaper --set-output '../HDMI-1' "$external"; then
  fail 'unsafe output name was accepted'
fi
[[ "$(readlink "$TMP/state/i3/wallpapers")" == "$generation_before" ]] ||
  fail 'invalid output changed state'

# Legacy single-file state migrates into one atomic connector generation.
rm -f "$TMP/state/i3/wallpapers"
rm -rf "$TMP/state/i3/wallpaper-layouts"
printf '%s\n' "$shared" >"$TMP/state/i3/wallpaper"
: >"$TMP/calls"
run_wallpaper --restore
grep -Fxq "feh <--bg-fill> <$shared> <$shared>" "$TMP/calls" || fail 'legacy restore failed'
[[ -L "$TMP/state/i3/wallpapers" ]] || fail 'legacy state did not migrate atomically'
[[ "$(cat "$TMP/state/i3/wallpapers/eDP-1")" == "$shared" ]] || fail 'legacy eDP migration missing'
[[ "$(cat "$TMP/state/i3/wallpapers/HDMI-1")" == "$shared" ]] || fail 'legacy HDMI migration missing'

# Empty/invalid restore reports an actionable error.
mkdir -p "$TMP/empty-home" "$TMP/empty-state" "$TMP/empty-wallpapers"
: >"$TMP/notifications"
if CALLS="$TMP/empty.calls" NOTIFY_CALLS="$TMP/notifications" HOME="$TMP/empty-home" \
  XDG_STATE_HOME="$TMP/empty-state" I3_WALLPAPER_DIR="$TMP/empty-wallpapers" \
  PATH="$TMP/bin:$PATH" "$HELPER" --restore; then
  fail 'empty restore unexpectedly succeeded'
fi
grep -Fq 'No hay fondos válidos guardados' "$TMP/notifications" ||
  fail 'empty restore did not notify user'

printf 'PASS: wallpaper state follows pointer/focus monitor and restores each output\n'
