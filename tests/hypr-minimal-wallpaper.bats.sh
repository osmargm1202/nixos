#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$repo_dir/dotfiles/config/profiles/hyprland/.local/bin/hypr-wallpaper"
current_script="$repo_dir/dotfiles/config/profiles/hyprland/.local/bin/hypr-current-wallpaper"
tmp="$(mktemp -d)"
unmanaged_pid=''

cleanup() {
  local pid starttime pid_file
  if [[ -s "$runtime/hypr-wallpaper-mpvpaper.pid" ]]; then
    read -r pid starttime <"$runtime/hypr-wallpaper-mpvpaper.pid" || true
    [[ -n "${pid:-}" ]] && kill -TERM -- "-$pid" 2>/dev/null || true
  fi
  for pid_file in "$runtime/hypr-wallpaper-mpvpaper-monitors"/*.pid; do
    [[ -s "$pid_file" ]] || continue
    read -r pid starttime <"$pid_file" || true
    [[ -n "${pid:-}" ]] && kill -TERM -- "-$pid" 2>/dev/null || true
  done
  if [[ -s "$tmp/hyprpaper.pid" ]]; then
    kill -TERM "$(cat "$tmp/hyprpaper.pid")" 2>/dev/null || true
  fi
  [[ -n "$unmanaged_pid" ]] && kill -TERM -- "-$unmanaged_pid" 2>/dev/null || true
  rm -rf "$tmp"
}
trap cleanup EXIT

bin="$tmp/bin"
home="$tmp/home"
runtime="$tmp/runtime"
state="$tmp/state"
mkdir -p "$bin" "$home/Pictures/Wallpapers" "$runtime" "$state"
printf 'fallback' >"$home/Pictures/Wallpapers/xnm1-background.png"

cat >"$bin/hyprpaper" <<'EOF'
#!/usr/bin/env bash
touch "$HYPRPAPER_READY"
printf '%s\n' "$$" >"$HYPRPAPER_PID"
trap 'exit 0' TERM INT
while :; do sleep 1; done
EOF
cat >"$bin/hyprctl" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == 'hyprpaper listactive' ]]; then
  [[ -f "$HYPRPAPER_READY" ]] || exit 1
  exit 0
fi
if [[ "$*" == '-j monitors' ]]; then
  printf '%s\n' '[{"name":"DP-1"},{"name":"HDMI-A-1"},{"name":"eDP-1"}]'
  exit 0
fi
printf '%s\n' "$*" >>"$HYPRPAPER_CALLS"
EOF
cat >"$bin/mpvpaper" <<'EOF'
#!/usr/bin/env bash
printf '<%s>' "$@" >>"$MPVPAPER_CALLS"
printf '\n' >>"$MPVPAPER_CALLS"
trap 'exit 0' TERM INT
while :; do sleep 1; done
EOF
cat >"$bin/unmanaged" <<'EOF'
#!/usr/bin/env bash
trap 'exit 0' TERM INT
while :; do sleep 1; done
EOF
chmod +x "$bin/hyprpaper" "$bin/hyprctl" "$bin/mpvpaper" "$bin/unmanaged"

export HOME="$home"
export XDG_RUNTIME_DIR="$runtime"
export XDG_STATE_HOME="$state"
export PATH="$bin:$PATH"
export HYPRPAPER_READY="$tmp/hyprpaper-ready"
export HYPRPAPER_PID="$tmp/hyprpaper.pid"
export HYPRPAPER_CALLS="$tmp/hyprpaper-calls"
export MPVPAPER_CALLS="$tmp/mpvpaper-calls"
export HYPRCTL_BIN="$bin/hyprctl"
export HYPRPAPER_BIN="$bin/hyprpaper"
export MPVPAPER_BIN="$bin/mpvpaper"

"$script" restore
fallback="$home/Pictures/Wallpapers/xnm1-background.png"
[[ "$(<"$state/hypr-wallpaper/current")" == "$fallback" ]]
[[ "$(readlink "$runtime/hypr-current-wallpaper")" == "$fallback" ]]
grep -Fq ", $fallback, cover" "$HYPRPAPER_CALLS"
rm "$state/hypr-wallpaper/current"
"$current_script" >/dev/null
[[ "$(readlink "$runtime/hypr-current-wallpaper")" == "$fallback" ]]

custom_dir="$home/Custom-Wallpapers"
mkdir -p "$custom_dir" "$custom_dir/.thumb"
printf 'thumbnail' >"$custom_dir/.thumb/ignored.jpg"
printf 'custom' >"$custom_dir/custom.webp"
"$script" random "$custom_dir"
custom="$custom_dir/custom.webp"
[[ "$(<"$state/hypr-wallpaper/current")" == "$custom" ]]
[[ "$(readlink "$runtime/hypr-current-wallpaper")" == "$custom" ]]
grep -Fq ", $custom, cover" "$HYPRPAPER_CALLS"

hyprpaper_calls_before_invalid_hide="$(wc -l <"$HYPRPAPER_CALLS")"
if "$script" hide extra >/dev/null 2>&1; then
  echo 'FAIL: wallpaper hide must reject extra arguments' >&2
  exit 1
fi
[[ "$(<"$state/hypr-wallpaper/current")" == "$custom" ]]
[[ "$(readlink "$runtime/hypr-current-wallpaper")" == "$custom" ]]
[[ "$(wc -l <"$HYPRPAPER_CALLS")" -eq "$hyprpaper_calls_before_invalid_hide" ]]

image_applications_before="$(grep -Fc ", $custom, cover" "$HYPRPAPER_CALLS")"
"$script" hide
grep -Fxq 'hyprpaper unload all' "$HYPRPAPER_CALLS"
[[ "$(<"$state/hypr-wallpaper/current")" == "$custom" ]]
[[ "$(readlink "$runtime/hypr-current-wallpaper")" == "$custom" ]]
"$script" restore
[[ "$(grep -Fc ", $custom, cover" "$HYPRPAPER_CALLS")" -eq $((image_applications_before + 1)) ]]

thumb_only_dir="$home/Thumbs-only"
mkdir -p "$thumb_only_dir/.thumb"
printf 'thumbnail only' >"$thumb_only_dir/.thumb/ignored.jpg"
if "$script" random "$thumb_only_dir"; then
  echo 'FAIL: wallpaper selector must ignore a directory containing only .thumb images' >&2
  exit 1
fi

default_dir="$home/Pictures/Wallpapers"
"$script" random
default="$default_dir/xnm1-background.png"
[[ "$(<"$state/hypr-wallpaper/current")" == "$default" ]]
grep -Fq ", $default, cover" "$HYPRPAPER_CALLS"

video="$home/animated background.mp4"
printf 'video' >"$video"
"$script" set "$video"
[[ "$(<"$state/hypr-wallpaper/current")" == "$video" ]]
read -r first_pid first_start <"$runtime/hypr-wallpaper-mpvpaper.pid"
[[ "$first_pid" =~ ^[0-9]+$ && "$first_start" =~ ^[0-9]+$ ]]
kill -0 "$first_pid" 2>/dev/null
[[ "$(readlink "$runtime/hypr-current-wallpaper")" == "$fallback" ]]
grep -Fq "<-o><no-audio loop hwdec=auto panscan=1.0><ALL><$video>" "$MPVPAPER_CALLS"
"$current_script" >/dev/null
[[ "$(readlink "$runtime/hypr-current-wallpaper")" == "$fallback" ]]

setsid "$bin/unmanaged" >/dev/null 2>&1 &
unmanaged_pid=$!
sleep 0.05
"$script" hide
[[ ! -e "$runtime/hypr-wallpaper-mpvpaper.pid" ]]
! kill -0 -- "-$first_pid" 2>/dev/null
kill -0 "$unmanaged_pid" 2>/dev/null
[[ "$(<"$state/hypr-wallpaper/current")" == "$video" ]]
[[ "$(readlink "$runtime/hypr-current-wallpaper")" == "$fallback" ]]
"$script" restore
read -r restored_pid restored_start <"$runtime/hypr-wallpaper-mpvpaper.pid"
[[ "$first_pid:$first_start" != "$restored_pid:$restored_start" ]]
kill -0 "$restored_pid" 2>/dev/null
[[ "$(<"$state/hypr-wallpaper/current")" == "$video" ]]

next_video="$home/second background.webm"
printf 'video' >"$next_video"
"$script" set "$next_video"
read -r second_pid second_start <"$runtime/hypr-wallpaper-mpvpaper.pid"
[[ "$first_pid:$first_start" != "$second_pid:$second_start" ]]
! kill -0 -- "-$first_pid" 2>/dev/null
[[ "$(<"$state/hypr-wallpaper/current")" == "$next_video" ]]

"$script" set "$custom"
[[ ! -e "$runtime/hypr-wallpaper-mpvpaper.pid" ]]
! kill -0 -- "-$second_pid" 2>/dev/null
kill -0 "$unmanaged_pid" 2>/dev/null
[[ "$(readlink "$runtime/hypr-current-wallpaper")" == "$custom" ]]

global_video="$home/global background.avi"
monitor_static="$home/monitor static.png"
monitor_video="$home/monitor video.mkv"
printf 'video' >"$global_video"
printf 'static' >"$monitor_static"
printf 'video' >"$monitor_video"
"$script" set "$global_video"
read -r global_pid global_start <"$runtime/hypr-wallpaper-mpvpaper.pid"
"$script" set "$monitor_static" --monitor DP-1
[[ "$(<"$state/hypr-wallpaper/current")" == "$global_video" ]]
grep -Fxq 'mode=static' "$state/hypr-wallpaper/monitors/DP-1.state"
grep -Fxq "path=$monitor_static" "$state/hypr-wallpaper/monitors/DP-1.state"
grep -Fq "DP-1, $monitor_static, cover" "$HYPRPAPER_CALLS"
[[ ! -e "$runtime/hypr-wallpaper-mpvpaper.pid" ]]
! kill -0 -- "-$global_pid" 2>/dev/null
read -r default_pid default_start <"$runtime/hypr-wallpaper-mpvpaper-monitors/eDP-1.pid"
kill -0 "$default_pid" 2>/dev/null
grep -Fq "<-o><no-audio loop hwdec=auto panscan=1.0><eDP-1><$global_video>" "$MPVPAPER_CALLS"

"$script" set "$monitor_video" --monitor HDMI-A-1
grep -Fxq 'mode=video' "$state/hypr-wallpaper/monitors/HDMI-A-1.state"
grep -Fxq "path=$monitor_video" "$state/hypr-wallpaper/monitors/HDMI-A-1.state"
read -r monitor_pid monitor_start <"$runtime/hypr-wallpaper-mpvpaper-monitors/HDMI-A-1.pid"
kill -0 "$monitor_pid" 2>/dev/null
grep -Fq "<-o><no-audio loop hwdec=auto panscan=1.0><HDMI-A-1><$monitor_video>" "$MPVPAPER_CALLS"
read -r default_pid default_start <"$runtime/hypr-wallpaper-mpvpaper-monitors/eDP-1.pid"
kill -0 "$default_pid" 2>/dev/null

if "$script" set "$monitor_static" --monitor '../unsafe' >/dev/null 2>&1; then
  echo 'FAIL: monitor wallpaper must reject unsafe output names' >&2
  exit 1
fi

"$script" hide
! kill -0 -- "-$monitor_pid" 2>/dev/null
! kill -0 -- "-$default_pid" 2>/dev/null
grep -Fxq 'mode=static' "$state/hypr-wallpaper/monitors/DP-1.state"
grep -Fxq 'mode=video' "$state/hypr-wallpaper/monitors/HDMI-A-1.state"
"$script" restore
[[ ! -e "$runtime/hypr-wallpaper-mpvpaper.pid" ]]
read -r restored_monitor_pid restored_monitor_start <"$runtime/hypr-wallpaper-mpvpaper-monitors/HDMI-A-1.pid"
kill -0 "$restored_monitor_pid" 2>/dev/null
read -r restored_default_pid restored_default_start <"$runtime/hypr-wallpaper-mpvpaper-monitors/eDP-1.pid"
kill -0 "$restored_default_pid" 2>/dev/null
grep -Fq "DP-1, $monitor_static, cover" "$HYPRPAPER_CALLS"
grep -Fq "<-o><no-audio loop hwdec=auto panscan=1.0><HDMI-A-1><$monitor_video>" "$MPVPAPER_CALLS"

"$script" set "$custom"
[[ ! -e "$state/hypr-wallpaper/monitors/DP-1.state" ]]
[[ ! -e "$state/hypr-wallpaper/monitors/HDMI-A-1.state" ]]
[[ ! -e "$runtime/hypr-wallpaper-mpvpaper-monitors/HDMI-A-1.pid" ]]
! kill -0 -- "-$restored_monitor_pid" 2>/dev/null
! kill -0 -- "-$restored_default_pid" 2>/dev/null
kill -0 "$unmanaged_pid" 2>/dev/null

# A first-run per-monitor selection must not need a global/default wallpaper.
rm "$state/hypr-wallpaper/current"
"$script" set "$monitor_static" --monitor DP-1
"$script" hide
: >"$HYPRPAPER_CALLS"
HYPR_WALLPAPER_DIR="$tmp/no-default-directory" "$script" restore
grep -Fq "DP-1, $monitor_static, cover" "$HYPRPAPER_CALLS"

printf '%s\n' 'hypr-minimal-wallpaper: ok'
