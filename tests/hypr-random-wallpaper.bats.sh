#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$REPO_DIR/config/shared/.local/bin/hypr-random-wallpaper"
TMP_BIN_DIR="$(mktemp -d)"
ORGM_HYPR_BIN="$TMP_BIN_DIR/orgm-hypr"

trap 'rm -rf "$TMP_BIN_DIR"' EXIT

go build -o "$ORGM_HYPR_BIN" "$REPO_DIR/cmd/orgm-hypr"

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

make_stub() {
	local dir="$1" name="$2" body="$3"
	printf '#!/usr/bin/env bash\nset -euo pipefail\n%s\n' "$body" >"$dir/bin/$name"
	chmod +x "$dir/bin/$name"
}

make_default_stubs() {
	local tmp="$1"
	mkdir -p "$tmp/bin" "$tmp/home/Pictures/Wallpapers" "$tmp/home/Videos/wallpapers" "$tmp/runtime" "$tmp/state"
	: >"$tmp/calls"

	cp "$ORGM_HYPR_BIN" "$tmp/bin/orgm-hypr"
	make_stub "$tmp" hyprpaper 'echo "hyprpaper $*" >>"$CALLS"'
	make_stub "$tmp" mpvpaper 'echo "mpvpaper $*" >>"$CALLS"'
	make_stub "$tmp" nvidia-offload 'echo "nvidia-offload $*" >>"$CALLS"'
	make_stub "$tmp" pkill 'echo "pkill $*" >>"$CALLS"; exit 0'
	make_stub "$tmp" pgrep 'exit 1'
	make_stub "$tmp" ps 'echo "ps $*" >>"$CALLS"; case "$*" in *424242*) echo "bash unrelated" ;; *515151*) echo "orgm-hypr wallpaper daemon" ;; *616161*) echo "quickshell -p /tmp/wallpaper-picker" ;; *31337*) echo "mpvpaper -o no-audio loop" ;; esac'
	make_stub "$tmp" test-kill 'echo "test-kill $*" >>"$CALLS"; exit 0'
	make_stub "$tmp" sleep 'echo "sleep $*" >>"$CALLS"; exit 0'
	make_stub "$tmp" shuf 'head -n 1'
	make_stub "$tmp" notify-send 'echo "notify-send $*" >>"$CALLS"; exit 0'
	make_stub "$tmp" fuzzel 'cat >"$MENU"; printf "%s\n" "$PICK"'
	make_stub "$tmp" quickshell 'echo "quickshell $* HYPR_WALLPAPER_DATA=${HYPR_WALLPAPER_DATA:-} HYPR_WALLPAPER_REQUEST=${HYPR_WALLPAPER_REQUEST:-}" >>"$CALLS"; exit 0'
	make_stub "$tmp" ffmpeg 'echo "ffmpeg $*" >>"$CALLS"; printf thumb >"${@: -1}"'
}

run_script() {
	local tmp="$1" command="$2"
	shift 2
	PATH="$tmp/bin:/usr/bin:/bin" \
		CALLS="$tmp/calls" \
		MENU="$tmp/menu" \
		HOME="$tmp/home" \
		XDG_RUNTIME_DIR="$tmp/runtime" \
		XDG_STATE_HOME="$tmp/state" \
		XDG_CONFIG_HOME="$tmp/home/.config" \
		HYPR_WALLPAPER_INTERVAL=999 \
		HYPR_WALLPAPER_KILL_BIN="${HYPR_WALLPAPER_KILL_BIN:-test-kill}" \
		HYPR_MPV_WALLPAPER_GPU="${HYPR_MPV_WALLPAPER_GPU:-integrated}" \
		PICK="${PICK:-}" \
		/bin/sh "$SCRIPT" "$command" "$@" >"$tmp/out" 2>"$tmp/err"
}

assert_calls_contains() {
	local tmp="$1" pattern="$2" name="$3"
	grep -qE "$pattern" "$tmp/calls" || {
		dump_case "$tmp"
		fail "$name expected calls to match: $pattern"
	}
}

assert_calls_not_contains() {
	local tmp="$1" pattern="$2" name="$3"
	if grep -qE "$pattern" "$tmp/calls"; then
		dump_case "$tmp"
		fail "$name expected calls not to match: $pattern"
	fi
}

assert_file_contains() {
	local file="$1" pattern="$2" name="$3"
	grep -qE "$pattern" "$file" || {
		echo "--- $file ---" >&2
		cat "$file" >&2 2>/dev/null || true
		fail "$name expected file to match: $pattern"
	}
}

assert_file_not_contains() {
	local file="$1" pattern="$2" name="$3"
	if grep -qE "$pattern" "$file"; then
		echo "--- $file ---" >&2
		cat "$file" >&2 2>/dev/null || true
		fail "$name expected file not to match: $pattern"
	fi
}

dump_case() {
	local tmp="$1"
	echo "--- calls ---" >&2
	cat "$tmp/calls" >&2 2>/dev/null || true
	echo "--- menu ---" >&2
	cat "$tmp/menu" >&2 2>/dev/null || true
	echo "--- stdout ---" >&2
	cat "$tmp/out" >&2 2>/dev/null || true
	echo "--- stderr ---" >&2
	cat "$tmp/err" >&2 2>/dev/null || true
}

with_tmp() {
	local tmp rc
	tmp="$(mktemp -d)"
	make_default_stubs "$tmp"
	"$@" "$tmp"
	rc=$?
	rm -rf "$tmp"
	return "$rc"
}

export SCRIPT
export -f fail make_stub make_default_stubs run_script \
	assert_calls_contains assert_calls_not_contains assert_file_contains assert_file_not_contains \
	dump_case with_tmp

test_pick_video_uses_mpvpaper_and_persists_video_mode() {
	with_tmp bash -c '
    tmp="$1"
    home="$tmp/home"
    video="$home/Videos/wallpapers/live.mp4"
    touch "$video"
    printf "515151\n" >"$tmp/runtime/hypr-random-wallpaper.daemon.pid"
    run_script "$tmp" set-video "$video"
    assert_calls_contains "$tmp" "test-kill -KILL 515151" "video mode stops stale wallpaper daemon"
    assert_calls_contains "$tmp" "pkill -x hyprpaper" "video mode stops static wallpaper"
    assert_calls_contains "$tmp" "mpvpaper -o no-audio loop hwdec=auto \* $video" "video mode starts mpvpaper"
    state="$tmp/state/hypr-wallpaper/state"
    assert_file_contains "$state" "^mode=video$" "video mode persisted"
    assert_file_contains "$state" "^path=$video$" "video path persisted"
  ' bash
}

test_pick_static_uses_hyprpaper_and_stops_mpvpaper() {
	with_tmp bash -c '
    tmp="$1"
    home="$tmp/home"
    image="$home/Pictures/Wallpapers/static.png"
    touch "$image"
    run_script "$tmp" set-static "$image"
    assert_calls_not_contains "$tmp" "pkill -x mpvpaper" "static mode avoids broad mpvpaper kill"
    assert_calls_contains "$tmp" "pkill -f .*mpvpaper .*wallpapers" "static mode stops live wallpaper commands"
    assert_calls_contains "$tmp" "hyprpaper -c $tmp/runtime/hypr-random-wallpaper.hyprpaper.conf" "static mode starts hyprpaper"
    conf="$tmp/runtime/hypr-random-wallpaper.hyprpaper.conf"
    assert_file_contains "$conf" "^wallpaper \\{$" "hyprpaper config uses current wallpaper block syntax"
    assert_file_contains "$conf" "^    monitor = \\*$" "hyprpaper config targets all monitors"
    assert_file_contains "$conf" "^    fit_mode = cover$" "hyprpaper config uses cover mode"
    assert_file_contains "$conf" "^    path = $image$" "hyprpaper config targets selected image"
    assert_file_not_contains "$conf" "^preload =" "hyprpaper config avoids legacy preload syntax"
    assert_file_not_contains "$conf" "^wallpaper =" "hyprpaper config avoids legacy wallpaper assignment"
    assert_file_not_contains "$conf" "^render \\{" "hyprpaper config avoids unsupported render block"
    assert_file_not_contains "$conf" "explicit_sync" "hyprpaper config avoids unsupported explicit_sync option"
    assert_file_not_contains "$conf" "direct_scanout" "hyprpaper config avoids unsupported direct_scanout option"
    state="$tmp/state/hypr-wallpaper/state"
    assert_file_contains "$state" "^mode=static$" "static mode persisted"
    assert_file_contains "$state" "^path=$image$" "static path persisted"
  ' bash
}

test_next_opens_single_wallpaper_menu() {
	with_tmp bash -c '
    tmp="$1"
    home="$tmp/home"
    video="$home/Videos/wallpapers/next.mp4"
    touch "$video"
    mkdir -p "$tmp/state/hypr-wallpaper"
    printf "mode=video\npath=%s\n" "$video" >"$tmp/state/hypr-wallpaper/state"
    PICK="" run_script "$tmp" next
    assert_file_contains "$tmp/menu" "^Normal$" "next opens fuzzel wallpaper menu"
    assert_calls_not_contains "$tmp" "quickshell .*wallpaper-picker" "next does not open carousel until mode selection"
    assert_calls_not_contains "$tmp" "mpvpaper -o" "next does not directly start mpvpaper"
    assert_calls_not_contains "$tmp" "hyprpaper -c" "next does not directly start hyprpaper"
  ' bash
}

test_restore_uses_persisted_static_or_video_without_randomizing() {
	with_tmp bash -c '
    tmp="$1"
    home="$tmp/home"
    image="$home/Pictures/Wallpapers/kept.png"
    touch "$image" "$home/Pictures/Wallpapers/other.png"
    mkdir -p "$tmp/state/hypr-wallpaper"
    printf "mode=static\npath=%s\n" "$image" >"$tmp/state/hypr-wallpaper/state"
    run_script "$tmp" restore
    assert_calls_contains "$tmp" "hyprpaper -c $tmp/runtime/hypr-random-wallpaper.hyprpaper.conf" "restore static starts hyprpaper"
    assert_file_contains "$tmp/runtime/hypr-random-wallpaper.hyprpaper.conf" "$image" "restore keeps persisted static image"
  ' bash

	with_tmp bash -c '
    tmp="$1"
    home="$tmp/home"
    video="$home/Videos/wallpapers/kept.mp4"
    touch "$video" "$home/Videos/wallpapers/other.mp4"
    mkdir -p "$tmp/state/hypr-wallpaper"
    printf "mode=video\npath=%s\n" "$video" >"$tmp/state/hypr-wallpaper/state"
    run_script "$tmp" restore
    assert_calls_contains "$tmp" "mpvpaper -o no-audio loop hwdec=auto \* $video" "restore keeps persisted video"
  ' bash
}

test_pick_uses_fuzzel_menu_and_opens_quickshell_normal_carousel() {
	with_tmp bash -c '
    tmp="$1"
    home="$tmp/home"
    image="$home/Pictures/Wallpapers/a.png"
    video="$home/Videos/wallpapers/a.mp4"
    touch "$image" "$video"
    PICK="Normal" run_script "$tmp" pick
    assert_file_contains "$tmp/menu" "^Normal$" "fuzzel menu lists normal"
    assert_file_contains "$tmp/menu" "^Normal Random$" "fuzzel menu lists normal random"
    assert_file_contains "$tmp/menu" "^Live$" "fuzzel menu lists live"
    assert_file_contains "$tmp/menu" "^Live Random$" "fuzzel menu lists live random"
    assert_calls_contains "$tmp" "quickshell -p $home/.config/quickshell/wallpaper-picker" "normal choice opens quickshell carousel"
    data="$tmp/state/hypr-wallpaper/wallpaper-picker.json"
    mode_data="$tmp/state/hypr-wallpaper/wallpaper-picker-static.json"
    request="$tmp/state/hypr-wallpaper/wallpaper-picker-request.json"
    assert_file_contains "$request" "wallpaper-picker-static.json" "normal carousel request points to static data"
    assert_file_contains "$mode_data" "\"mode\": \"static\"" "normal carousel writes static mode data file"
    assert_file_contains "$data" "\"title\": \"Normal wallpapers\"" "normal carousel data title is rendered"
    assert_file_contains "$data" "\"applyCommand\": \"set-static\"" "normal carousel applies static command"
    assert_file_contains "$data" "$image" "normal carousel includes image path"
    assert_file_contains "$data" "$home/Pictures/Wallpapers/.thumb/" "normal carousel uses folder-local thumbnail cache"
  ' bash
}

test_wallpaper_changes_do_not_send_success_notifications() {
	with_tmp bash -c '
    tmp="$1"
    home="$tmp/home"
    image="$home/Pictures/Wallpapers/no-notify.png"
    video="$home/Videos/wallpapers/no-notify.mp4"
    touch "$image" "$video"
    run_script "$tmp" set-static "$image"
    run_script "$tmp" set-video "$video"
    assert_calls_not_contains "$tmp" "notify-send" "successful wallpaper changes should stay silent"
  ' bash
}

test_quickshell_carousel_launches_without_generating_thumbnails() {
	with_tmp bash -c '
    tmp="$1"
    home="$tmp/home"
    for i in $(seq 1 20); do touch "$home/Pictures/Wallpapers/$i.png"; done
    run_script "$tmp" carousel static
    ffmpeg_count="$(grep -c "^ffmpeg " "$tmp/calls" || true)"
    [ "$ffmpeg_count" -eq 0 ] || {
      dump_case "$tmp"
      fail "carousel should launch before generating thumbnails, got $ffmpeg_count"
    }
    data="$tmp/state/hypr-wallpaper/wallpaper-picker.json"
    mode_data="$tmp/state/hypr-wallpaper/wallpaper-picker-static.json"
    request="$tmp/state/hypr-wallpaper/wallpaper-picker-request.json"
    manifest="$tmp/state/hypr-wallpaper/wallpaper-picker.tsv"
    assert_file_contains "$request" "wallpaper-picker-static.json" "request points at mode-specific data"
    assert_file_contains "$mode_data" "\"mode\": \"static\"" "mode-specific json is written"
    item_count="$(grep -c "\"path\":" "$data" || true)"
    manifest_count="$(wc -l <"$manifest")"
    [ "$item_count" -eq 20 ] || fail "json should still include all items"
    [ "$manifest_count" -eq 20 ] || fail "manifest should include all items for lazy warming"
  ' bash
}

test_thumbnails_are_reused_from_folder_local_cache() {
	with_tmp bash -c '
    tmp="$1"
    home="$tmp/home"
    image="$home/Pictures/Wallpapers/cached.png"
    touch "$image"
    mkdir -p "$home/Pictures/Wallpapers/.thumb"
    thumb="$home/Pictures/Wallpapers/.thumb/cached.png.jpg"
    printf cached >"$thumb"
    run_script "$tmp" carousel static
    assert_calls_not_contains "$tmp" "^ffmpeg " "existing .thumb cache avoids regeneration"
    data="$tmp/state/hypr-wallpaper/wallpaper-picker.json"
    assert_file_contains "$data" "$thumb" "json points to existing folder-local thumbnail"
  ' bash
}

test_carousel_removes_stale_static_thumbnails_only() {
	with_tmp bash -c '
    tmp="$1"
    home="$tmp/home"
    root="$home/Pictures/Wallpapers"
    valid="$root/current.png"
    stale_thumb="$root/.thumb/removed.png.jpg"
    valid_thumb="$root/.thumb/current.png.jpg"
    nested_valid="$root/nested/keep.webp"
    nested_stale_thumb="$root/nested/.thumb/gone.jpg.jpg"
    thumb_subdir_file="$root/.thumb/album/personal.jpg"
    touch "$valid"
    mkdir -p "$root/.thumb/album" "$root/nested/.thumb"
    touch "$nested_valid"
    printf stale >"$stale_thumb"
    printf valid >"$valid_thumb"
    printf nested-stale >"$nested_stale_thumb"
    printf keep >"$thumb_subdir_file"

    run_script "$tmp" carousel static

    [ ! -e "$stale_thumb" ] || fail "stale static thumbnail should be removed"
    [ ! -e "$nested_stale_thumb" ] || fail "nested stale static thumbnail should be removed"
    [ -e "$valid_thumb" ] || fail "valid static thumbnail should be kept"
    [ -e "$thumb_subdir_file" ] || fail "files below .thumb subdirectories should be kept"
    assert_calls_not_contains "$tmp" "^ffmpeg " "static cleanup must not generate thumbnails"
  ' bash
}

test_carousel_removes_stale_video_thumbnails_only() {
	with_tmp bash -c '
    tmp="$1"
    home="$tmp/home"
    root="$home/Videos/wallpapers"
    valid="$root/current.mp4"
    stale_thumb="$root/.thumb/removed.mp4.jpg"
    valid_thumb="$root/.thumb/current.mp4.jpg"
    touch "$valid"
    mkdir -p "$root/.thumb"
    printf stale >"$stale_thumb"
    printf valid >"$valid_thumb"

    run_script "$tmp" carousel video

    [ ! -e "$stale_thumb" ] || fail "stale video thumbnail should be removed"
    [ -e "$valid_thumb" ] || fail "valid video thumbnail should be kept"
    assert_calls_not_contains "$tmp" "^ffmpeg " "video cleanup must not generate thumbnails"
  ' bash
}

test_warm_thumbs_all_generates_only_missing_thumbnails() {
	with_tmp bash -c '
    tmp="$1"
    home="$tmp/home"
    for i in $(seq 1 5); do touch "$home/Pictures/Wallpapers/$i.png"; done
    mkdir -p "$home/Pictures/Wallpapers/.thumb"
    first="$home/Pictures/Wallpapers/1.png"
    first_thumb="$home/Pictures/Wallpapers/.thumb/1.png.jpg"
    printf cached >"$first_thumb"
    run_script "$tmp" carousel static
    : >"$tmp/calls"
    run_script "$tmp" warm-thumbs static all
    ffmpeg_count="$(grep -c "^ffmpeg " "$tmp/calls" || true)"
    [ "$ffmpeg_count" -eq 4 ] || {
      dump_case "$tmp"
      fail "warm-thumbs all should generate only 4 missing thumbnails, got $ffmpeg_count"
    }
  ' bash
}

test_warm_page_generates_only_requested_4x4_page() {
	with_tmp bash -c '
    tmp="$1"
    home="$tmp/home"
    for i in $(seq 1 40); do touch "$home/Pictures/Wallpapers/$i.png"; done
    run_script "$tmp" carousel static
    : >"$tmp/calls"
    run_script "$tmp" warm-page static 1 16
    ffmpeg_count="$(grep -c "^ffmpeg " "$tmp/calls" || true)"
    [ "$ffmpeg_count" -eq 16 ] || {
      dump_case "$tmp"
      fail "warm-page should generate exactly 16 thumbnails, got $ffmpeg_count"
    }
  ' bash
}

test_warm_thumbs_generates_near_selected_index_only() {
	with_tmp bash -c '
    tmp="$1"
    home="$tmp/home"
    for i in $(seq 1 20); do touch "$home/Pictures/Wallpapers/$i.png"; done
    run_script "$tmp" carousel static
    : >"$tmp/calls"
    run_script "$tmp" warm-thumbs static 10
    ffmpeg_count="$(grep -c "^ffmpeg " "$tmp/calls" || true)"
    [ "$ffmpeg_count" -eq 11 ] || {
      dump_case "$tmp"
      fail "warm-thumbs should generate 11 nearby thumbnails, got $ffmpeg_count"
    }
  ' bash
}

test_pick_live_random_applies_without_carousel() {
	with_tmp bash -c '
    tmp="$1"
    home="$tmp/home"
    video="$home/Videos/wallpapers/random.mp4"
    touch "$video"
    PICK="Live Random" run_script "$tmp" pick
    assert_calls_not_contains "$tmp" "quickshell .*wallpaper-picker" "random choices do not open carousel"
    assert_calls_contains "$tmp" "mpvpaper -o no-audio loop hwdec=auto \* $video" "live random applies video"
  ' bash
}

test_process_cleanup_is_scoped_to_wallpaper_processes() {
	with_tmp bash -c '
    tmp="$1"
    home="$tmp/home"
    video="$home/Videos/wallpapers/scoped.mp4"
    touch "$video"
    run_script "$tmp" set-video "$video"
    assert_calls_not_contains "$tmp" "pkill -x mpvpaper" "cleanup should not kill unrelated mpvpaper by executable name"
    assert_calls_contains "$tmp" "pkill -f .*mpvpaper .*wallpapers" "cleanup kills only wallpaper mpvpaper commands"
  ' bash
}

test_video_start_stops_previous_processes_and_records_pid() {
	with_tmp bash -c '
    tmp="$1"
    home="$tmp/home"
    video="$home/Videos/wallpapers/pid.mp4"
    touch "$video"
    mkdir -p "$tmp/state/hypr-wallpaper"
    printf "not-a-real-pid\n" >"$tmp/runtime/hypr-random-wallpaper.mpvpaper.pid"
    run_script "$tmp" set-video "$video"
    assert_calls_not_contains "$tmp" "pkill -x mpvpaper" "video start avoids broad exact mpvpaper kill"
    assert_calls_contains "$tmp" "pkill -f .*mpvpaper .*wallpapers" "video start kills wrapper mpvpaper commands"
    [ -s "$tmp/runtime/hypr-random-wallpaper.mpvpaper.pid" ] || fail "mpvpaper pid file should be written"
  ' bash
}

test_stale_pid_does_not_kill_unrelated_process() {
	with_tmp bash -c '
    tmp="$1"
    home="$tmp/home"
    video="$home/Videos/wallpapers/safe-pid.mp4"
    touch "$video"
    printf "424242\n" >"$tmp/runtime/hypr-random-wallpaper.mpvpaper.pid"
    run_script "$tmp" set-video "$video"
    assert_calls_contains "$tmp" "ps -p 424242 -o command=" "stale pid is inspected"
    assert_calls_not_contains "$tmp" "test-kill -TERM 424242" "unrelated pid is not killed"
    assert_calls_not_contains "$tmp" "test-kill -KILL 424242" "unrelated pid is not force killed"
  ' bash
}

test_mpvpaper_pid_is_killed_when_command_matches() {
	with_tmp bash -c '
    tmp="$1"
    home="$tmp/home"
    video="$home/Videos/wallpapers/safe-pid.mp4"
    touch "$video"
    printf "31337\n" >"$tmp/runtime/hypr-random-wallpaper.mpvpaper.pid"
    run_script "$tmp" set-video "$video"
    assert_calls_contains "$tmp" "ps -p 31337 -o command=" "mpvpaper pid is inspected"
    assert_calls_contains "$tmp" "test-kill -TERM 31337" "mpvpaper pid is terminated"
  ' bash
}

test_static_mode_stops_host_mpvpaper_from_distrobox() {
	with_tmp bash -c '
    tmp="$1"
    home="$tmp/home"
    image="$home/Pictures/Wallpapers/host-static.png"
    touch "$image"
    make_stub "$tmp" distrobox-host-exec "echo distrobox-host-exec \"\$*\" >>\"\$CALLS\""
    run_script "$tmp" set-static "$image"
    assert_calls_contains "$tmp" "distrobox-host-exec sh -lc .*pkill -f .*mpvpaper .*wallpapers" "static mode kills host mpvpaper when host exec exists"
  ' bash
}

test_carousel_static_and_video_use_distinct_picker_files() {
	with_tmp bash -c '
    tmp="$1"
    home="$tmp/home"
    image="$home/Pictures/Wallpapers/normal.png"
    video="$home/Videos/wallpapers/live.mp4"
    touch "$image" "$video"
    run_script "$tmp" carousel static
    static_data="$tmp/state/hypr-wallpaper/wallpaper-picker-static.json"
    request="$tmp/state/hypr-wallpaper/wallpaper-picker-request.json"
    assert_file_contains "$request" "wallpaper-picker-static.json" "static request points to static file"
    assert_file_contains "$static_data" "\"mode\": \"static\"" "static data contains static mode"
    run_script "$tmp" carousel video
    video_data="$tmp/state/hypr-wallpaper/wallpaper-picker-video.json"
    assert_file_contains "$request" "wallpaper-picker-video.json" "video request points to video file"
    assert_file_contains "$video_data" "\"mode\": \"video\"" "video data contains video mode"
    assert_file_contains "$static_data" "\"mode\": \"static\"" "static file stays static after video request"
  ' bash
}

test_visible_carousel_restarts_resident_picker_for_fresh_mode() {
	with_tmp bash -c '
    tmp="$1"
    home="$tmp/home"
    image="$home/Pictures/Wallpapers/normal.png"
    touch "$image"
    make_stub "$tmp" pgrep '\''echo 616161; exit 0'\''
    run_script "$tmp" carousel static
    assert_calls_contains "$tmp" "pkill -f quickshell .*wallpaper-picker" "visible carousel stops stale resident picker"
    assert_calls_contains "$tmp" "quickshell -p $home/.config/quickshell/wallpaper-picker" "visible carousel launches fresh picker"
    assert_file_contains "$tmp/state/hypr-wallpaper/wallpaper-picker-request.json" "wallpaper-picker-static.json" "fresh picker request points to selected static data"
  ' bash
}

test_carousel_does_not_mix_current_from_other_mode() {
	with_tmp bash -c '
    tmp="$1"
    home="$tmp/home"
    image="$home/Pictures/Wallpapers/normal.png"
    video="$home/Videos/wallpapers/live.mp4"
    touch "$image" "$video"
    mkdir -p "$tmp/state/hypr-wallpaper"
    printf "mode=video\npath=%s\n" "$video" >"$tmp/state/hypr-wallpaper/state"
    run_script "$tmp" carousel static
    data="$tmp/state/hypr-wallpaper/wallpaper-picker.json"
    assert_file_contains "$data" "$image" "static carousel includes static image"
    if grep -q "$video" "$data"; then
      dump_case "$tmp"
      fail "static carousel must not include current video path"
    fi
  ' bash
}

test_nvidia_offload_is_used_when_auto_and_available() {
	with_tmp bash -c '
    tmp="$1"
    home="$tmp/home"
    video="$home/Videos/wallpapers/gpu.mp4"
    touch "$video"
    HYPR_MPV_WALLPAPER_GPU=auto run_script "$tmp" set-video "$video"
    assert_calls_contains "$tmp" "nvidia-offload .*mpvpaper -o no-audio loop hwdec=auto \* $video" "auto mode uses nvidia-offload when available"
  ' bash
}

test_nvidia_offload_can_be_forced_off() {
	with_tmp bash -c '
    tmp="$1"
    home="$tmp/home"
    video="$home/Videos/wallpapers/gpu-off.mp4"
    touch "$video"
    HYPR_MPV_WALLPAPER_GPU=integrated run_script "$tmp" set-video "$video"
    assert_calls_not_contains "$tmp" "nvidia-offload .*mpvpaper -o" "integrated mode bypasses nvidia-offload launcher"
    assert_calls_contains "$tmp" "mpvpaper -o no-audio loop hwdec=auto \* $video" "integrated mode starts mpvpaper directly"
  ' bash
}

test_distrobox_branch_checks_nvidia_offload_on_host() {
	with_tmp bash -c '
    tmp="$1"
    home="$tmp/home"
    video="$home/Videos/wallpapers/host-gpu.mp4"
    touch "$video"
    rm -f "$tmp/bin/mpvpaper" "$tmp/bin/nvidia-offload"
    make_stub "$tmp" distrobox-host-exec "echo distrobox-host-exec \"\$*\" >>\"\$CALLS\""
    HYPR_MPV_WALLPAPER_GPU=auto run_script "$tmp" set-video "$video"
    assert_calls_contains "$tmp" "distrobox-host-exec sh -lc .*command -v nvidia-offload.*nvidia-offload mpvpaper" "distrobox mode checks nvidia-offload on host"
  ' bash
}

test_pick_video_uses_mpvpaper_and_persists_video_mode
test_pick_static_uses_hyprpaper_and_stops_mpvpaper
test_next_opens_single_wallpaper_menu
test_restore_uses_persisted_static_or_video_without_randomizing
test_pick_uses_fuzzel_menu_and_opens_quickshell_normal_carousel
test_wallpaper_changes_do_not_send_success_notifications
test_quickshell_carousel_launches_without_generating_thumbnails
test_thumbnails_are_reused_from_folder_local_cache
test_carousel_removes_stale_static_thumbnails_only
test_carousel_removes_stale_video_thumbnails_only
test_warm_thumbs_all_generates_only_missing_thumbnails
test_warm_page_generates_only_requested_4x4_page
test_warm_thumbs_generates_near_selected_index_only
test_pick_live_random_applies_without_carousel
test_process_cleanup_is_scoped_to_wallpaper_processes
test_video_start_stops_previous_processes_and_records_pid
test_stale_pid_does_not_kill_unrelated_process
test_mpvpaper_pid_is_killed_when_command_matches
test_static_mode_stops_host_mpvpaper_from_distrobox
test_visible_carousel_restarts_resident_picker_for_fresh_mode
test_carousel_does_not_mix_current_from_other_mode
test_nvidia_offload_is_used_when_auto_and_available
test_nvidia_offload_can_be_forced_off
test_distrobox_branch_checks_nvidia_offload_on_host

echo "hypr-random-wallpaper tests passed"
