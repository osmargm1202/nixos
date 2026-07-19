#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HELPER="$ROOT/config/shared/.local/bin/steam-workshop-image"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[[ -x "$HELPER" ]] || fail 'steam-workshop-image missing or not executable'
mkdir -p "$TMP/bin" "$TMP/steam" "$TMP/workshop" "$TMP/dest"
cat > "$TMP/bin/steamcmd" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$CALLS"
exit "${STEAMCMD_STATUS:-0}"
STUB
chmod +x "$TMP/bin/steamcmd"

run_helper() {
  CALLS="$TMP/calls" \
  STEAM_ROOT="$TMP/steam" \
  STEAM_WORKSHOP_ROOT="$TMP/workshop" \
  STEAM_WALLPAPER_DEST="$TMP/dest" \
  PATH="$TMP/bin:$PATH" \
  "$HELPER" "$@"
}

: > "$TMP/calls"
if run_helper 'not-an-id' >"$TMP/invalid.out" 2>"$TMP/invalid.err"; then
  fail 'invalid input succeeded'
fi
[[ ! -s "$TMP/calls" ]] || fail 'invalid input called SteamCMD'

mkdir -p "$TMP/workshop/111"
printf 'main-image\n' > "$TMP/workshop/111/main.png"
printf 'preview-image\n' > "$TMP/workshop/111/preview.jpg"
cat > "$TMP/workshop/111/project.json" <<'JSON'
{"title":"My Cool Wallpaper!","type":"scene","file":"main.png","preview":"preview.jpg"}
JSON
: > "$TMP/calls"
output="$(run_helper 111)"
[[ "$output" == "$TMP/dest/111-My-Cool-Wallpaper.png" ]] || fail "unexpected raw-ID output: $output"
grep -Fxq "+force_install_dir $TMP/steam +login anonymous +workshop_download_item 431960 111 validate +quit" "$TMP/calls" || fail 'SteamCMD raw-ID arguments incorrect'
[[ "$(cat "$output")" == main-image ]] || fail 'project image was not preferred'

mkdir -p "$TMP/workshop/222"
printf 'scene-data\n' > "$TMP/workshop/222/scene.pkg"
printf 'preview-two\n' > "$TMP/workshop/222/cover.JPG"
cat > "$TMP/workshop/222/project.json" <<'JSON'
{"title":"Scene / Night","type":"scene","file":"scene.pkg","preview":"cover.JPG"}
JSON
: > "$TMP/calls"
output="$(run_helper 'https://steamcommunity.com/sharedfiles/filedetails/?id=222&searchtext=night')"
[[ "$output" == "$TMP/dest/222-Scene-Night.jpg" ]] || fail "unexpected URL output: $output"
grep -Fq '+workshop_download_item 431960 222 validate' "$TMP/calls" || fail 'URL ID was not extracted'
[[ "$(cat "$output")" == preview-two ]] || fail 'preview fallback was not copied'

mkdir -p "$TMP/workshop/333"
printf 'scene-data\n' > "$TMP/workshop/333/scene.pkg"
printf '{"title":"No Image","type":"scene","file":"scene.pkg"}\n' > "$TMP/workshop/333/project.json"
if run_helper 333 >"$TMP/no-image.out" 2>"$TMP/no-image.err"; then
  fail 'item without image succeeded'
fi
if find "$TMP/dest" -maxdepth 1 -type f -name '333-*' | grep -q .; then
  fail 'item without image created destination'
fi

printf 'PASS: Steam Workshop image helper\n'
