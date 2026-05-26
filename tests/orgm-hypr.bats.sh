#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_BIN_DIR="$(mktemp -d)"
BIN="$TMP_BIN_DIR/orgm-hypr"

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

trap 'rm -rf "$TMP_BIN_DIR" "${tmp:-}"' EXIT

go build -o "$BIN" "$REPO_DIR/cmd/orgm-hypr"

version="$($BIN version)"
[ "$version" = "orgm-hypr dev" ] || fail "unexpected version output: $version"

tmp="$(mktemp -d)"
mkdir -p "$tmp/Pictures/Wallpapers" "$tmp/Videos/wallpapers"
touch "$tmp/Pictures/Wallpapers/normal.png" "$tmp/Videos/wallpapers/live.mp4"
manifest="$tmp/wallpaper-picker.tsv"
json="$tmp/wallpaper-picker.json"
{
	printf 'static\t%s/Pictures/Wallpapers/normal.png\n' "$tmp"
	printf 'video\t%s/Videos/wallpapers/live.mp4\n' "$tmp"
} >"$manifest"

"$BIN" wallpaper data \
	--mode static \
	--manifest "$manifest" \
	--json "$json" \
	--current "$tmp/Pictures/Wallpapers/normal.png" \
	--script hypr-random-wallpaper

grep -q '"mode": "static"' "$json" || fail "json missing static mode"
grep -q '"title": "Normal wallpapers"' "$json" || fail "json missing static title"
grep -q '"applyCommand": "set-static"' "$json" || fail "json missing set-static command"
grep -q '"script": "hypr-random-wallpaper"' "$json" || fail "json missing script"
grep -q '"path": '"\"$tmp/Pictures/Wallpapers/normal.png\"" "$json" || fail "json missing static path"
grep -q '"thumb": '"\"$tmp/Pictures/Wallpapers/.thumb/normal.png.jpg\"" "$json" || fail "json missing folder-local thumb"
if grep -q 'live.mp4' "$json"; then
	cat "$json" >&2
	fail "static json should not include video item"
fi

"$BIN" wallpaper data \
	--mode video \
	--manifest "$manifest" \
	--json "$json" \
	--script orgm-hypr \
	--script-arg wallpaper

grep -q '"script": "orgm-hypr"' "$json" || fail "json missing orgm-hypr script"
grep -q '"scriptArgs": \[' "$json" || fail "json missing scriptArgs"
grep -q '"wallpaper"' "$json" || fail "json missing wallpaper script arg"

PATH="$TMP_BIN_DIR:$PATH" HOME="$tmp" XDG_RUNTIME_DIR="$tmp/runtime" XDG_STATE_HOME="$tmp/state" "$BIN" wallpaper status >"$tmp/status"
grep -q '^mode=static-random$' "$tmp/status" || fail "status should default to static-random"

mkdir -p "$tmp/Pictures/Wallpapers/.thumb" "$tmp/Pictures/Wallpapers/.thumb/album"
valid_thumb="$tmp/Pictures/Wallpapers/.thumb/normal.png.jpg"
stale_thumb="$tmp/Pictures/Wallpapers/.thumb/removed.png.jpg"
thumb_subdir_file="$tmp/Pictures/Wallpapers/.thumb/album/personal.jpg"
printf valid >"$valid_thumb"
printf stale >"$stale_thumb"
printf keep >"$thumb_subdir_file"
"$BIN" wallpaper clean-thumbs --root "$tmp/Pictures/Wallpapers"
[ -e "$valid_thumb" ] || fail "valid thumb should remain"
[ ! -e "$stale_thumb" ] || fail "stale thumb should be removed"
[ -e "$thumb_subdir_file" ] || fail "thumb subdirectory file should remain"

echo "orgm-hypr smoke tests passed"
