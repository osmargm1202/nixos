#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-wallpaper"
WRAPPER="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-set-wallpaper"
PROFILE="$ROOT/nixos/profiles/i3.nix"
TMP="$(mktemp -d)"
cleanup() {
  local pid child
  if [[ -d "$TMP/state/i3/video-pids" ]]; then
    while read -r pid _; do
      [[ "$pid" =~ ^[0-9]+$ ]] && kill -TERM -- "-$pid" 2>/dev/null || true
      [[ "$pid" =~ ^[0-9]+$ ]] && kill -KILL -- "-$pid" 2>/dev/null || true
    done < <(cat "$TMP/state/i3/video-pids"/* 2>/dev/null || true)
  fi
  if [[ -f "$TMP/video.children" ]]; then
    while read -r child; do
      [[ "$child" =~ ^[0-9]+$ ]] && kill -KILL "$child" 2>/dev/null || true
    done <"$TMP/video.children"
  fi
  rm -rf "$TMP"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

for package in mpv xwinwrap; do
  grep -Eq "^[[:space:]]+${package}[[:space:]]*$" "$PROFILE" || fail "$package package missing"
done
grep -Fq 'exec i3-wallpaper --set-active "$1"' "$WRAPPER" || fail 'Thunar wrapper does not delegate active-output media'
grep -Fq '*.mp4|*.mkv|*.webm|*.mov|*.m4v|*.avi' "$HELPER" || fail 'video extensions are not accepted'
grep -Fq 'setsid "$xwinwrap_bin"' "$HELPER" || fail 'xwinwrap process group is not isolated'
grep -Fq '"$mpv_bin" -wid WID' "$HELPER" ||
  fail 'mpv must use the xwinwrap-compatible split WID argument'
if grep -Fq -- '-fdt' "$HELPER"; then
  fail 'NixOS xwinwrap v4 does not support the -fdt option'
fi

mkdir -p "$TMP/bin" "$TMP/home" "$TMP/state" "$TMP/wallpapers"
cat >"$TMP/bin/xrandr" <<'STUB'
#!/usr/bin/env bash
case "${1:-}" in
  --listactivemonitors)
    printf 'Monitors: 2\n 0: +*eDP-1 1920/309x1080/174+0+0 eDP-1\n 1: +HDMI-1 1920/509x1080/286+1920+0 HDMI-1\n'
    ;;
  --query)
    printf 'eDP-1 connected primary 1920x1080+0+0\nHDMI-1 connected 1920x1080+1920+0\n'
    ;;
  *) exit 2 ;;
esac
STUB
cat >"$TMP/bin/xdotool" <<'STUB'
#!/usr/bin/env bash
printf 'X=%s\nY=200\nSCREEN=0\nWINDOW=1\n' "${POINTER_X:-2200}"
STUB
cat >"$TMP/bin/feh" <<'STUB'
#!/usr/bin/env bash
printf 'feh' >>"$FEH_CALLS"
printf ' <%s>' "$@" >>"$FEH_CALLS"
printf '\n' >>"$FEH_CALLS"
STUB
cat >"$TMP/bin/ffmpeg" <<'STUB'
#!/usr/bin/env bash
input=''
previous=''
for argument in "$@"; do
  [[ "$previous" == -i ]] && input="$argument"
  previous="$argument"
done
cp -- "$input" "${!#}"
STUB
cat >"$TMP/bin/xwinwrap" <<'STUB'
#!/usr/bin/env bash
printf '%s' "$$" >>"$VIDEO_CALLS"
printf ' <%s>' "$@" >>"$VIDEO_CALLS"
printf '\n' >>"$VIDEO_CALLS"
# Simulate an embedded mpv descendant that ignores TERM, forcing group KILL.
bash -c 'trap "" TERM; while :; do /run/current-system/sw/bin/sleep 1; done' &
printf '%s\n' "$!" >>"$VIDEO_CHILDREN"
trap 'exit 0' TERM INT
while :; do /run/current-system/sw/bin/sleep 1; done
STUB
cat >"$TMP/bin/mpv" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
cat >"$TMP/bin/notify-send" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
cat >"$TMP/bin/shuf" <<'STUB'
#!/usr/bin/env bash
head -n1
STUB
chmod +x "$TMP/bin/"*

image="$TMP/wallpapers/still image.jpg"
replacement="$TMP/wallpapers/replacement.png"
video="$TMP/wallpapers/animated background.mp4"
printf image >"$image"
printf image >"$replacement"
printf video >"$video"

run_wallpaper() {
  HOME="$TMP/home" XDG_STATE_HOME="$TMP/state" I3_WALLPAPER_DIR="$TMP/wallpapers" \
    PATH="$TMP/bin:$PATH" FEH_CALLS="$TMP/feh.calls" VIDEO_CALLS="$TMP/video.calls" \
    VIDEO_CHILDREN="$TMP/video.children" POINTER_X="${POINTER_X:-2200}" "$HELPER" "$@"
}

run_wallpaper --set "$image"
lock_image="$TMP/state/i3/lock_screen.png"
[[ "$(cat "$TMP/state/i3/lock_screen")" == "$lock_image" ]] ||
  fail 'still wallpaper did not publish a lock image pointer'
cmp -s "$image" "$lock_image" || fail 'JPG wallpaper was not converted for i3lock'
: >"$TMP/feh.calls"
: >"$TMP/video.calls"
run_wallpaper --set-active "$video"
[[ "$(cat "$TMP/state/i3/wallpapers/HDMI-1")" == "$video" ]] || fail 'video path was not persisted for HDMI'
grep -Fq '<-g> <1920x1080+1920+0>' "$TMP/video.calls" || fail 'video used wrong HDMI geometry'
grep -Fq '<-g> <1920x1080+1920+0> <-ni> <-b> <-nf> <-ov>' "$TMP/video.calls" ||
  fail 'xwinwrap desktop flags incomplete'
grep -Fq '<-wid> <WID>' "$TMP/video.calls" || fail 'xwinwrap did not receive a replaceable WID argument'
for option in '--loop-file=inf' '--no-audio' '--no-osc' '--no-osd-bar' '--no-input-default-bindings' '--panscan=1.0' '--really-quiet'; do
  grep -Fq "<$option>" "$TMP/video.calls" || fail "mpv option missing: $option"
done
grep -Fq "<$video>" "$TMP/video.calls" || fail 'mpv did not receive selected video'
[[ -f "$TMP/state/i3/video-pids/HDMI-1" ]] || fail 'HDMI video process state missing'
read -r first_pid first_start <"$TMP/state/i3/video-pids/HDMI-1"
first_child="$(tail -n1 "$TMP/video.children")"
kill -0 "$first_pid" 2>/dev/null || fail 'xwinwrap process is not alive'
kill -0 "$first_child" 2>/dev/null || fail 'embedded mpv child is not alive'
placeholder="$TMP/state/i3/video-placeholder.ppm"
grep -Fxq "feh <--bg-fill> <$image> <$placeholder>" "$TMP/feh.calls" ||
  fail 'video output did not retain a static root placeholder'

# Restore restarts video using persisted connector state and current geometry.
: >"$TMP/video.calls"
run_wallpaper --restore
read -r restored_pid restored_start <"$TMP/state/i3/video-pids/HDMI-1"
restored_child="$(tail -n1 "$TMP/video.children")"
[[ "$restored_pid:$restored_start" != "$first_pid:$first_start" ]] || fail 'restore did not refresh video process'
kill -0 "$first_child" 2>/dev/null && fail 'stubborn child survived restore cleanup'
grep -Fq '<1920x1080+1920+0>' "$TMP/video.calls" || fail 'restored video geometry missing'

# Replacing the video with an image terminates its managed process group.
POINTER_X=2200 run_wallpaper --set-active "$replacement"
[[ ! -e "$TMP/state/i3/video-pids/HDMI-1" ]] || fail 'stale HDMI video PID state remains'
kill -0 "$restored_pid" 2>/dev/null && fail 'old HDMI xwinwrap process survived image replacement'
kill -0 "$restored_child" 2>/dev/null && fail 'embedded mpv child survived image replacement'


printf 'PASS: Thunar and per-monitor state support X11 video wallpapers\n'
