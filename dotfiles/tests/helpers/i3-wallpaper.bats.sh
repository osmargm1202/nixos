#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HELPER="$ROOT/config/profiles/i3/.local/bin/i3-wallpaper"
NAUTILUS="$ROOT/config/profiles/i3/.local/share/nautilus/scripts/Set as Wallpaper"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[ -x "$HELPER" ] || fail 'i3-wallpaper helper missing or not executable'
[ -x "$NAUTILUS" ] || fail 'Nautilus Set as Wallpaper script missing or not executable'
bash -n "$HELPER" "$NAUTILUS"

mkdir -p "$TMP/bin" "$TMP/home" "$TMP/state" "$TMP/wallpapers"
cat >"$TMP/bin/feh" <<'STUB'
#!/usr/bin/env bash
printf 'feh' >>"$CALLS"
printf ' <%s>' "$@" >>"$CALLS"
printf '\n' >>"$CALLS"
STUB
cat >"$TMP/bin/notify-send" <<'STUB'
#!/usr/bin/env bash
printf 'notify-send %s\n' "$*" >>"$CALLS"
STUB
cat >"$TMP/bin/shuf" <<'STUB'
#!/usr/bin/env bash
head -n1
STUB
chmod +x "$TMP/bin/"*

image="$TMP/wallpapers/selected image.png"
printf 'image\n' >"$image"
CALLS="$TMP/set.calls" HOME="$TMP/home" XDG_STATE_HOME="$TMP/state" \
  I3_WALLPAPER_DIR="$TMP/wallpapers" PATH="$TMP/bin:$PATH" \
  "$HELPER" --set "$image"
grep -Fxq "feh <--bg-fill> <$image>" "$TMP/set.calls" || fail 'set must apply selected image through Feh'
[[ "$(cat "$TMP/state/i3/wallpaper")" == "$image" ]] || fail 'set must persist selected image'
if grep -Fq -- '--no-fehbg' "$TMP/set.calls"; then
  fail 'Feh must remain free to maintain ~/.fehbg'
fi

: >"$TMP/restore.calls"
CALLS="$TMP/restore.calls" HOME="$TMP/home" XDG_STATE_HOME="$TMP/state" \
  I3_WALLPAPER_DIR="$TMP/wallpapers" PATH="$TMP/bin:$PATH" \
  "$HELPER" --restore
grep -Fxq "feh <--bg-fill> <$image>" "$TMP/restore.calls" || fail 'restore must apply persisted image'

printf 'not image\n' >"$TMP/wallpapers/invalid.txt"
if CALLS="$TMP/invalid.calls" HOME="$TMP/home" XDG_STATE_HOME="$TMP/state" \
  I3_WALLPAPER_DIR="$TMP/wallpapers" PATH="$TMP/bin:$PATH" \
  "$HELPER" --set "$TMP/wallpapers/invalid.txt"; then
  fail 'invalid wallpaper extension must be rejected'
fi
if grep -q '^feh' "$TMP/invalid.calls"; then
  fail 'invalid wallpaper must not call Feh'
fi

rm "$TMP/state/i3/wallpaper" "$image" "$TMP/wallpapers/invalid.txt"
printf 'fallback\n' >"$TMP/wallpapers/a-fallback.jpg"
CALLS="$TMP/random.calls" HOME="$TMP/home" XDG_STATE_HOME="$TMP/state" \
  I3_WALLPAPER_DIR="$TMP/wallpapers" PATH="$TMP/bin:$PATH" \
  "$HELPER" --restore
grep -Fq 'a-fallback.jpg' "$TMP/random.calls" || fail 'restore without state must choose fallback image'

: >"$TMP/direct-random.calls"
CALLS="$TMP/direct-random.calls" HOME="$TMP/home" XDG_STATE_HOME="$TMP/state" \
  I3_WALLPAPER_DIR="$TMP/wallpapers" PATH="$TMP/bin:$PATH" \
  "$HELPER" --random
grep -Fq 'a-fallback.jpg' "$TMP/direct-random.calls" || fail 'random command must apply an available image'

cat >"$TMP/bin/i3-wallpaper" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$CALLS"
STUB
chmod +x "$TMP/bin/i3-wallpaper"
CALLS="$TMP/nautilus.calls" PATH="$TMP/bin:$PATH" \
  NAUTILUS_SCRIPT_SELECTED_FILE_PATHS="$image"$'\n' \
  "$NAUTILUS"
grep -Fxq -- "--set $image" "$TMP/nautilus.calls" || fail 'Nautilus script must delegate selected path'

if CALLS="$TMP/nautilus-multi.calls" PATH="$TMP/bin:$PATH" \
  NAUTILUS_SCRIPT_SELECTED_FILE_PATHS="$image"$'\n'"$TMP/wallpapers/a-fallback.jpg"$'\n' \
  "$NAUTILUS"; then
  fail 'Nautilus script must reject multiple selections'
fi
if grep -q '^--set ' "$TMP/nautilus-multi.calls"; then
  fail 'multiple selection must not change wallpaper'
fi

printf 'PASS: i3 wallpaper set, restore, fallback and Nautilus delegation\n'
