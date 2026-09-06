#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$repo_dir/dotfiles/config/profiles/hyprland/.local/bin/hypr-wallpaper"
current_script="$repo_dir/dotfiles/config/profiles/hyprland/.local/bin/hypr-current-wallpaper"
tmp="$(mktemp -d)"
unrelated_pid=''
auto_hyprpaper_pid=''
outputs=(DP-1 HDMI-A-1 eDP-1)

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

stop_pid_file() {
  local file="$1" pid starttime
  [[ -s "$file" ]] || return 0
  read -r pid starttime <"$file" || return 0
  [[ "$pid" =~ ^[0-9]+$ ]] && kill -TERM -- "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
}

cleanup() {
  local pid_file kind pid ignored
  stop_pid_file "$runtime/hypr-wallpaper-mpvpaper.pid"
  stop_pid_file "$runtime/hypr-wallpaper-hyprpaper.pid"
  for pid_file in "$runtime/hypr-wallpaper-mpvpaper-monitors"/*.pid; do
    stop_pid_file "$pid_file"
  done
  if [[ -r "${WALLPAPER_EVENTS:-}" ]]; then
    while read -r kind pid ignored; do
      case "$kind" in start|mpv-start) ;; *) continue ;; esac
      [[ "$pid" =~ ^[0-9]+$ ]] || continue
      kill -TERM -- "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
    done <"$WALLPAPER_EVENTS"
  fi
  [[ -n "$auto_hyprpaper_pid" ]] && kill -TERM -- "-$auto_hyprpaper_pid" 2>/dev/null || true
  [[ -n "$unrelated_pid" ]] && kill -TERM -- "-$unrelated_pid" 2>/dev/null || true
  rm -rf "$tmp"
}
trap cleanup EXIT

assert_file_value() {
  local file="$1" expected="$2"
  [[ -f "$file" ]] || fail "missing surface: $file"
  [[ "$(<"$file")" -ef "$expected" ]] || fail "surface $file did not show $expected"
}
assert_owned_process() {
  local file="$1" pid starttime actual
  [[ -s "$file" ]] || fail "missing owned process record: $file"
  read -r pid starttime <"$file"
  [[ "$pid" =~ ^[0-9]+$ && "$starttime" =~ ^[0-9]+$ ]] ||
    fail "invalid owned process record: $file"
  kill -0 "$pid" 2>/dev/null || fail "recorded process is not alive: $file"
  actual="$(awk '{ print $22 }' "/proc/$pid/stat")"
  [[ "$actual" == "$starttime" ]] || fail "recorded process start time is stale: $file"
}

assert_no_monitor_video_owners() {
  ! compgen -G "$runtime/hypr-wallpaper-mpvpaper-monitors/*.pid" >/dev/null ||
    fail 'layout retained per-monitor mpvpaper ownership'
}
assert_no_retired_engine_leaks() {
  local kind pid ignored current_pids='' pid_file
  for pid_file in "$runtime/hypr-wallpaper-hyprpaper.pid" "$runtime/hypr-wallpaper-mpvpaper.pid" \
    "$runtime/hypr-wallpaper-mpvpaper-monitors"/*.pid; do
    [[ -s "$pid_file" ]] || continue
    read -r pid ignored <"$pid_file"
    current_pids+=" $pid"
  done
  while read -r kind pid ignored; do
    case "$kind" in start|mpv-start) ;; *) continue ;; esac
    [[ " $current_pids " == *" $pid "* ]] && continue
    ! kill -0 "$pid" 2>/dev/null || fail "retired $kind process is still alive: $pid"
  done <"$WALLPAPER_EVENTS"
}



assert_no_surface_overlap() {
  local output static=0 video=0
  for output in "${outputs[@]}"; do
    [[ -e "$hyprpaper_surfaces/$output" ]] && static=1 || static=0
    video=0
    [[ -e "$mpvpaper_surfaces/ALL" ]] && video=$((video + 1))
    [[ -e "$mpvpaper_surfaces/$output" ]] && video=$((video + 1))
    (( video <= 1 )) || fail "multiple video surfaces on $output"
    (( static + video <= 1 )) || fail "static and video surfaces overlap on $output"
  done
}

assert_all_static() {
  local wallpaper="$1" output
  [[ -e "$hyprpaper_ready" ]] || fail 'hyprpaper was not ready for static layout'
  [[ -s "$runtime/hypr-wallpaper-hyprpaper.pid" ]] || fail 'static layout did not record its Hyprpaper owner'
  assert_owned_process "$runtime/hypr-wallpaper-hyprpaper.pid"
  assert_no_monitor_video_owners
  [[ ! -e "$runtime/hypr-wallpaper-mpvpaper.pid" ]] || fail 'static layout retained global mpvpaper ownership'
  for output in "${outputs[@]}"; do
    assert_file_value "$hyprpaper_surfaces/$output" "$wallpaper"
    [[ ! -e "$mpvpaper_surfaces/$output" && ! -e "$mpvpaper_surfaces/ALL" ]] ||
      fail "static layout retained video surface on $output"
  done
  assert_no_surface_overlap
}

assert_global_video() {
  local wallpaper="$1" output
  [[ ! -e "$hyprpaper_ready" ]] || fail 'global video retained Hyprpaper daemon'
  [[ ! -e "$runtime/hypr-wallpaper-hyprpaper.pid" ]] || fail 'global video retained Hyprpaper ownership'
  [[ -s "$runtime/hypr-wallpaper-mpvpaper.pid" ]] || fail 'global video did not record mpvpaper ownership'
  assert_owned_process "$runtime/hypr-wallpaper-mpvpaper.pid"
  assert_no_monitor_video_owners
  assert_file_value "$mpvpaper_surfaces/ALL" "$wallpaper"
  for output in "${outputs[@]}"; do
    [[ ! -e "$hyprpaper_surfaces/$output" && ! -e "$mpvpaper_surfaces/$output" ]] ||
      fail "global video has an extra surface on $output"
  done
  assert_no_surface_overlap
}

assert_mixed_layout() {
  local static_wallpaper="$1" video_wallpaper="$2" output
  [[ -e "$hyprpaper_ready" ]] || fail 'mixed layout did not retain Hyprpaper for its static output'
  [[ ! -e "$runtime/hypr-wallpaper-mpvpaper.pid" ]] || fail 'mixed layout retained global mpvpaper'
  assert_file_value "$hyprpaper_surfaces/DP-1" "$static_wallpaper"
  assert_owned_process "$runtime/hypr-wallpaper-hyprpaper.pid"
  for output in HDMI-A-1 eDP-1; do
    [[ ! -e "$hyprpaper_surfaces/$output" ]] || fail "mixed layout left static surface on video output $output"
    assert_file_value "$mpvpaper_surfaces/$output" "$video_wallpaper"
    assert_owned_process "$runtime/hypr-wallpaper-mpvpaper-monitors/$output.pid"
  done
  [[ ! -e "$mpvpaper_surfaces/ALL" && ! -e "$mpvpaper_surfaces/DP-1" ]] ||
    fail 'mixed layout left a video surface on static output'
  assert_no_surface_overlap
}

bin="$tmp/bin"
home="$tmp/home"
runtime="$tmp/runtime"
state="$tmp/state"
hyprpaper_surfaces="$tmp/hyprpaper-surfaces"
mpvpaper_surfaces="$tmp/mpvpaper-surfaces"
hyprpaper_ready="$tmp/hyprpaper-ready"
mkdir -p "$bin" "$home/Pictures/Wallpapers" "$home/Videos/wallpapers" "$runtime" "$state" \
  "$hyprpaper_surfaces" "$mpvpaper_surfaces"
printf 'fallback' >"$home/Pictures/Wallpapers/xnm1-background.png"

cat >"$bin/hyprpaper" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

config=''
if [[ "${1:-}" == --config ]]; then
  config="${2:?missing Hyprpaper config}"
  shift 2
fi
[[ $# -eq 0 ]] || exit 2
if [[ -e "${HYPRPAPER_FAIL_START_FILE:-}" ]]; then
  rm -f -- "$HYPRPAPER_FAIL_START_FILE"
  printf 'simulated Hyprpaper start failure\n' >&2
  exit 1
fi
[[ -z "$config" || -f "$config" ]] || exit 2
[[ ! -e "$WALLPAPER_CLOSING" ]] || exit 1

config_entries() {
  local line output='' wallpaper='' spec value
  [[ -n "$config" ]] || return 0
  while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]]*wallpaper[[:space:]]*= ]]; then
      spec="${line#*=}"
      spec="${spec#"${spec%%[![:space:]]*}"}"
      output="${spec%%,*}"
      output="${output%"${output##*[![:space:]]}"}"
      wallpaper="${spec#*,}"
      wallpaper="${wallpaper#"${wallpaper%%[![:space:]]*}"}"
      wallpaper="${wallpaper%%,*}"
      wallpaper="${wallpaper%"${wallpaper##*[![:space:]]}"}"
      [[ -n "$output" && -n "$wallpaper" ]] && printf '%s\t%s\n' "$output" "$wallpaper"
      continue
    fi
    if [[ "$line" =~ ^[[:space:]]*wallpaper[[:space:]]*\{ ]]; then
      output=''
      wallpaper=''
      continue
    fi
    if [[ "$line" =~ ^[[:space:]]*monitor[[:space:]]*= ]]; then
      value="${line#*=}"
      value="${value%%;*}"
      output="${value#"${value%%[![:space:]]*}"}"
      output="${output%"${output##*[![:space:]]}"}"
      continue
    fi
    if [[ "$line" =~ ^[[:space:]]*path[[:space:]]*= ]]; then
      value="${line#*=}"
      value="${value%%;*}"
      wallpaper="${value#"${value%%[![:space:]]*}"}"
      wallpaper="${wallpaper%"${wallpaper##*[![:space:]]}"}"
      continue
    fi
    if [[ "$line" =~ ^[[:space:]]*\} ]] && [[ -n "$output" || -n "$wallpaper" ]]; then
      [[ -n "$output" && -n "$wallpaper" ]] && printf '%s\t%s\n' "$output" "$wallpaper"
      output=''
      wallpaper=''
    fi
  done <"$config"
}

# A replacement daemon must never create a static layer over an existing video
# layer. The helper must retire the conflicting engine first.
while IFS=$'\t' read -r output wallpaper; do
  [[ ! -e "$MPVPAPER_SURFACES/$output" && ! -e "$MPVPAPER_SURFACES/ALL" ]] || {
    printf 'refusing static/video overlap on %s\n' "$output" >&2
    exit 1
  }
done < <(config_entries)

rm -f -- "$HYPRPAPER_SURFACES"/*
while IFS=$'\t' read -r output wallpaper; do
  [[ -n "$output" && -n "$wallpaper" && -f "$wallpaper" ]] || exit 2
  printf '%s\n' "$wallpaper" >"$HYPRPAPER_SURFACES/$output"
done < <(config_entries)
printf 'start %s %s\n' "$$" "${config:-empty}" >>"$WALLPAPER_EVENTS"
printf '%s\n' "$$" >"$HYPRPAPER_PID"
touch "$HYPRPAPER_READY"
stopped=0
stop() {
  (( stopped )) && return
  stopped=1
  if [[ -r "$HYPRPAPER_PID" && "$(<"$HYPRPAPER_PID")" == "$$" ]]; then
    rm -f -- "$HYPRPAPER_READY" "$HYPRPAPER_PID" "$HYPRPAPER_SURFACES"/*
    touch "$WALLPAPER_CLOSING"
  fi
  printf 'stop %s\n' "$$" >>"$WALLPAPER_EVENTS"
}
trap 'stop; exit 0' TERM INT
trap stop EXIT
while :; do sleep 1; done
EOF

cat >"$bin/hyprctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >>"$HYPRPAPER_CALLS"
if [[ "$*" == 'hyprpaper listactive' ]]; then
  [[ -e "$HYPRPAPER_READY" ]] || exit 1
  for active in "$HYPRPAPER_SURFACES"/*; do
    [[ -f "$active" ]] || continue
    printf '%s = %s\n' "${active##*/}" "$(<"$active")"
  done
  exit 0
fi
if [[ "$*" == '-j monitors' ]]; then
  printf '%s\n' '[{"name":"DP-1"},{"name":"HDMI-A-1"},{"name":"eDP-1"}]'
  exit 0
fi
if [[ "$*" == '-j layers' ]]; then
  printf '{"fixture":{"levels":{"0":['
  separator=''
  if [[ -e "$WALLPAPER_CLOSING" ]]; then
    printf '{"namespace":"mpvpaper"}'
    separator=','
    rm -f -- "$WALLPAPER_CLOSING"
  fi
  for active in "$HYPRPAPER_SURFACES"/* "$MPVPAPER_SURFACES"/*; do
    [[ -f "$active" ]] || continue
    printf '%s{"namespace":"%s"}' "$separator" 'mpvpaper'
    separator=','
  done
  printf ']}}}\n'
  exit 0
fi
# Hyprpaper 0.8.4 provides neither unload nor clear IPC. Wallpaper IPC is
# intentionally rejected too: the lifecycle uses a generated daemon config.
printf 'unsupported Hyprpaper IPC: %s\n' "$*" >&2
exit 2
EOF


cat >"$bin/mpvpaper" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

[[ "${1:-}" == -o && $# -eq 4 ]] || exit 2
options="$2"
output="$3"
wallpaper="$4"
printf '<%s>' "$@" >>"$MPVPAPER_CALLS"
printf '\n' >>"$MPVPAPER_CALLS"
if [[ -e "${MPVPAPER_FAIL_START_FILE:-}" ]]; then
  rm -f -- "$MPVPAPER_FAIL_START_FILE"
  printf 'simulated mpvpaper start failure\n' >&2
  exit 1
fi
[[ ! -e "$WALLPAPER_CLOSING" ]] || exit 1
if [[ "$output" == ALL ]]; then
  for monitor in $HYPRPAPER_OUTPUTS; do
    [[ ! -e "$HYPRPAPER_SURFACES/$monitor" && ! -e "$MPVPAPER_SURFACES/$monitor" ]] || {
      printf 'refusing video overlap on %s\n' "$monitor" >&2
      exit 1
    }
  done
else
  [[ ! -e "$HYPRPAPER_SURFACES/$output" && ! -e "$MPVPAPER_SURFACES/$output" && ! -e "$MPVPAPER_SURFACES/ALL" ]] || {
    printf 'refusing video overlap on %s\n' "$output" >&2
    exit 1
  }
fi
printf '%s\n' "$wallpaper" >"$MPVPAPER_SURFACES/$output"
printf 'mpv-start %s %s %s\n' "$$" "$output" "$wallpaper" >>"$WALLPAPER_EVENTS"
stopped=0
stop() {
  (( stopped )) && return
  stopped=1
  [[ -e "$MPVPAPER_SURFACES/$output" && "$(<"$MPVPAPER_SURFACES/$output")" == "$wallpaper" ]] &&
    rm -f -- "$MPVPAPER_SURFACES/$output"
  printf 'mpv-stop %s %s\n' "$$" "$output" >>"$WALLPAPER_EVENTS"
  touch "$WALLPAPER_CLOSING"
}
trap 'stop; exit 0' TERM INT
trap stop EXIT
while :; do sleep 1; done
EOF

cat >"$bin/unmanaged" <<'EOF'
#!/usr/bin/env bash
trap 'exit 0' TERM INT
while :; do sleep 1; done
EOF

mkdir -p "$home/.local/bin"
cat >"$home/.local/bin/hypr-rofi-lib" <<'EOF'
hypr_rofi_dmenu() {
  local option found=0
  [[ -n "${HYPR_ROFI_CHOICE:-}" ]] || return 1
  while IFS= read -r option; do
    [[ "$option" == "$HYPR_ROFI_CHOICE" ]] && found=1
  done
  (( found )) || return 1
  printf '%s\n' "$HYPR_ROFI_CHOICE"
}
notify-send() {
  printf '<%s>' "$@" >>"${NOTIFY_CALLS:?}"
  printf '\n' >>"$NOTIFY_CALLS"
}
EOF

chmod +x "$bin/hyprpaper" "$bin/hyprctl" "$bin/mpvpaper" "$bin/unmanaged"
export HOME="$home"
export XDG_RUNTIME_DIR="$runtime"
export XDG_STATE_HOME="$state"
export PATH="$bin:$PATH"
export HYPRLAND_INSTANCE_SIGNATURE='wallpaper-test-session'
export WALLPAPER_CLOSING="$tmp/wallpaper-closing"
export HYPRCTL_BIN="$bin/hyprctl"
export HYPRPAPER_BIN="$bin/hyprpaper"
export MPVPAPER_BIN="$bin/mpvpaper"
export HYPR_ROFI_LIB="$home/.local/bin/hypr-rofi-lib"
export HYPRPAPER_READY="$hyprpaper_ready"
export HYPRPAPER_PID="$tmp/hyprpaper.pid"
export HYPRPAPER_SURFACES="$hyprpaper_surfaces"
export MPVPAPER_SURFACES="$mpvpaper_surfaces"
export HYPRPAPER_OUTPUTS="${outputs[*]}"
export HYPRPAPER_CALLS="$tmp/hyprpaper-calls"
export MPVPAPER_CALLS="$tmp/mpvpaper-calls"
export WALLPAPER_EVENTS="$tmp/wallpaper-events"
export NOTIFY_CALLS="$tmp/notify-calls"

# Model the old helper-created but untracked Hyprpaper daemon. It is valid for
# this Hyprland session, while the unrelated process below must remain intact.
initial_config="$tmp/initial-hyprpaper.conf"
printf 'wallpaper = DP-1, %s\nwallpaper = HDMI-A-1, %s\nwallpaper = eDP-1, %s\n' \
  "$home/Pictures/Wallpapers/xnm1-background.png" "$home/Pictures/Wallpapers/xnm1-background.png" \
  "$home/Pictures/Wallpapers/xnm1-background.png" >"$initial_config"
setsid "$bin/hyprpaper" --config "$initial_config" >/dev/null 2>&1 &
auto_hyprpaper_pid=$!
for _ in {1..20}; do [[ -e "$hyprpaper_ready" ]] && break; sleep 0.02; done
[[ -e "$hyprpaper_ready" ]] || fail 'fixture Hyprpaper did not start'
setsid "$bin/unmanaged" >/dev/null 2>&1 &
unrelated_pid=$!

fallback="$home/Pictures/Wallpapers/xnm1-background.png"
"$script" restore
[[ "$(<"$state/hypr-wallpaper/current")" == "$fallback" ]]
[[ "$(readlink "$runtime/hypr-current-wallpaper")" == "$fallback" ]]
assert_all_static "$fallback"
kill -0 "$unrelated_pid" 2>/dev/null || fail 'wallpaper helper touched unrelated process'

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
assert_all_static "$custom"

mixed_dir="$home/Mixed Media"
mkdir -p "$mixed_dir/nested"
current_static="$mixed_dir/current static.png"
alternate_static="$mixed_dir/nested/alternate
static.jpg"
mixed_video="$mixed_dir/nested/animated background.mp4"
printf 'current static' >"$current_static"
printf 'alternate static' >"$alternate_static"
printf 'video' >"$mixed_video"
"$script" set "$current_static"
static_pid_before_random="$(awk 'NR == 1 { print $1 }' "$runtime/hypr-wallpaper-hyprpaper.pid")"
"$script" random --type static "$mixed_dir"
[[ "$(<"$state/hypr-wallpaper/current")" == "$alternate_static" ]]
assert_all_static "$alternate_static"
! kill -0 "$static_pid_before_random" 2>/dev/null || fail 'repeated static change leaked Hyprpaper'
! kill -0 -- "-$static_pid_before_random" 2>/dev/null || fail 'repeated static change retained a Hyprpaper process group'
assert_no_retired_engine_leaks
"$script" random --type video "$mixed_dir"
[[ "$(<"$state/hypr-wallpaper/current")" == "$mixed_video" ]]
assert_global_video "$mixed_video"

static_only_dir="$home/Static only"
mkdir -p "$static_only_dir"
printf 'static' >"$static_only_dir/static.jpg"
state_before_empty_type="$(<"$state/hypr-wallpaper/current")"
if "$script" random --type video "$static_only_dir"; then
  fail 'empty requested media type must fail'
fi
[[ "$(<"$state/hypr-wallpaper/current")" == "$state_before_empty_type" ]]

"$script" set "$custom"
assert_all_static "$custom"
HYPR_ROFI_CHOICE='Cancel' "$script" random-menu
[[ "$(<"$state/hypr-wallpaper/current")" == "$custom" ]]
assert_all_static "$custom"
menu_start_failure="$tmp/fail-menu-mpvpaper-start"
touch "$menu_start_failure"
if MPVPAPER_FAIL_START_FILE="$menu_start_failure" HYPR_VIDEO_WALLPAPER_DIR="$mixed_dir" HYPR_ROFI_CHOICE='Video' "$script" random-menu; then
  fail 'random menu must fail when its wallpaper application fails'
fi
[[ "$(<"$state/hypr-wallpaper/current")" == "$custom" ]]
assert_all_static "$custom"


# Startup failures must leave the previous real layout and persisted choice in
# place. The fixture consumes each failure flag so rollback can actually start.
"$script" set "$mixed_video"
touch "$tmp/fail-hyprpaper-start"
export HYPRPAPER_FAIL_START_FILE="$tmp/fail-hyprpaper-start"
if "$script" set "$fallback"; then
  fail 'static startup failure must fail the requested change'
fi
unset HYPRPAPER_FAIL_START_FILE
[[ "$(<"$state/hypr-wallpaper/current")" == "$mixed_video" ]]
assert_global_video "$mixed_video"
"$script" set "$custom"

touch "$tmp/fail-mpvpaper-start"
export MPVPAPER_FAIL_START_FILE="$tmp/fail-mpvpaper-start"
if "$script" set "$mixed_video"; then
  fail 'video startup failure must fail the requested change'
fi
unset MPVPAPER_FAIL_START_FILE
[[ "$(<"$state/hypr-wallpaper/current")" == "$custom" ]]
assert_all_static "$custom"

if "$script" hide extra >/dev/null 2>&1; then
  fail 'wallpaper hide must reject extra arguments'
fi
"$script" hide
[[ "$(<"$state/hypr-wallpaper/current")" == "$custom" ]]
[[ ! -e "$hyprpaper_ready" && ! -e "$runtime/hypr-wallpaper-hyprpaper.pid" ]] ||
  fail 'hide retained Hyprpaper surface ownership'
[[ ! -e "$runtime/hypr-wallpaper-mpvpaper.pid" ]] && ! compgen -G "$mpvpaper_surfaces/*" >/dev/null ||
  fail 'hide retained mpvpaper surface ownership'
assert_no_monitor_video_owners
"$script" restore
assert_all_static "$custom"

thumb_only_dir="$home/Thumbs-only"
mkdir -p "$thumb_only_dir/.thumb"
printf 'thumbnail only' >"$thumb_only_dir/.thumb/ignored.jpg"
state_before_thumb_only="$(<"$state/hypr-wallpaper/current")"
if "$script" random "$thumb_only_dir"; then
  fail 'wallpaper selector must ignore a directory containing only .thumb images'
fi
[[ "$(<"$state/hypr-wallpaper/current")" == "$state_before_thumb_only" ]]

default_video="$home/Videos/wallpapers/default video.mp4"
printf 'video' >"$default_video"
"$script" random --type video
[[ "$(<"$state/hypr-wallpaper/current")" == "$default_video" ]]
assert_global_video "$default_video"
HYPR_ROFI_CHOICE='Video' "$script" random-menu
[[ "$(<"$state/hypr-wallpaper/current")" == "$default_video" ]]
assert_global_video "$default_video"

video="$home/animated background.mp4"
next_video="$home/second background.webm"
printf 'video' >"$video"
printf 'video' >"$next_video"
"$script" set "$video"
assert_global_video "$video"
"$script" set "$next_video"
read -r second_pid second_start <"$runtime/hypr-wallpaper-mpvpaper.pid"
assert_global_video "$next_video"
assert_no_retired_engine_leaks
"$script" set "$custom"
[[ ! -e "$runtime/hypr-wallpaper-mpvpaper.pid" ]]
! kill -0 -- "-$second_pid" 2>/dev/null || fail 'video-to-static change leaked mpvpaper'
assert_all_static "$custom"

# A mixed layout must have exactly one static daemon for static outputs and one
# video child per video output. No Hyprpaper fallback may sit below a video.
global_video="$home/global background.avi"
monitor_static="$home/monitor static.png"
monitor_video="$home/monitor video.mkv"
printf 'video' >"$global_video"
printf 'static' >"$monitor_static"
printf 'video' >"$monitor_video"
"$script" set "$global_video"
assert_global_video "$global_video"
"$script" set "$monitor_static" --monitor DP-1
assert_mixed_layout "$monitor_static" "$global_video"
"$script" set "$monitor_video" --monitor HDMI-A-1
assert_file_value "$hyprpaper_surfaces/DP-1" "$monitor_static"
assert_file_value "$mpvpaper_surfaces/HDMI-A-1" "$monitor_video"
assert_file_value "$mpvpaper_surfaces/eDP-1" "$global_video"
assert_no_surface_overlap

if "$script" set "$monitor_static" --monitor '../unsafe' >/dev/null 2>&1; then
  fail 'monitor wallpaper must reject unsafe output names'
fi

"$script" hide
[[ ! -e "$hyprpaper_ready" && ! -e "$runtime/hypr-wallpaper-hyprpaper.pid" ]] ||
  fail 'hide retained static daemon in mixed layout'
[[ ! -e "$mpvpaper_surfaces/ALL" && ! -e "$mpvpaper_surfaces/DP-1" && ! -e "$mpvpaper_surfaces/HDMI-A-1" && ! -e "$mpvpaper_surfaces/eDP-1" ]] ||
  fail 'hide retained video surface in mixed layout'
assert_no_retired_engine_leaks
"$script" restore
assert_file_value "$hyprpaper_surfaces/DP-1" "$monitor_static"
assert_file_value "$mpvpaper_surfaces/HDMI-A-1" "$monitor_video"
assert_file_value "$mpvpaper_surfaces/eDP-1" "$global_video"
assert_no_surface_overlap
# A first-run monitor selection has no global/default choice to fall back to,
# yet hide/restore must preserve its one-output static layout.
"$script" set "$custom"
rm "$state/hypr-wallpaper/current"
"$script" set "$monitor_static" --monitor DP-1
assert_owned_process "$runtime/hypr-wallpaper-hyprpaper.pid"
assert_file_value "$hyprpaper_surfaces/DP-1" "$monitor_static"
for output in HDMI-A-1 eDP-1; do
  [[ ! -e "$hyprpaper_surfaces/$output" && ! -e "$mpvpaper_surfaces/$output" ]] ||
    fail "first-run monitor selection created an extra surface on $output"
done
"$script" hide
HYPR_WALLPAPER_DIR="$tmp/no-default-directory" "$script" restore
assert_file_value "$hyprpaper_surfaces/DP-1" "$monitor_static"
assert_no_surface_overlap


# Concurrent callers must serialize through the helper lock and leave one valid
# topology, not stacked engine children. Either last request is valid.
"$script" set "$custom" &
static_request=$!
"$script" set "$video" &
video_request=$!
wait "$static_request"
wait "$video_request"
final_wallpaper="$(<"$state/hypr-wallpaper/current")"
case "$final_wallpaper" in
  "$custom") assert_all_static "$custom" ;;
  "$video") assert_global_video "$video" ;;
  *) fail "concurrent requests persisted unexpected wallpaper: $final_wallpaper" ;;
esac
assert_no_retired_engine_leaks
! grep -Fq 'hyprpaper unload' "$HYPRPAPER_CALLS" || fail 'helper attempted unsupported Hyprpaper unload IPC'
kill -0 "$unrelated_pid" 2>/dev/null || fail 'wallpaper helper touched unrelated process'

printf '%s\n' 'hypr-minimal-wallpaper: ok'
