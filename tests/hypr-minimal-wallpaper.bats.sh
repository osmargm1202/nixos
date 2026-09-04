#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$repo_dir/dotfiles/config/profiles/hyprland/.local/bin/hypr-wallpaper"
current_script="$repo_dir/dotfiles/config/profiles/hyprland/.local/bin/hypr-current-wallpaper"
tmp="$(mktemp -d)"
unmanaged_pid=''

cleanup() {
  local pid starttime
  if [[ -s "$runtime/hypr-wallpaper-mpvpaper.pid" ]]; then
    read -r pid starttime <"$runtime/hypr-wallpaper-mpvpaper.pid" || true
    [[ -n "${pid:-}" ]] && kill -TERM -- "-$pid" 2>/dev/null || true
  fi
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

printf '%s\n' 'hypr-minimal-wallpaper: ok'
