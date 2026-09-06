#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BIN="$ROOT/config/profiles/hyprland/.local/bin"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
CALLS="$TMP/calls.log"
: >"$CALLS"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  cat "$CALLS" >&2
  exit 1
}

assert_contains() {
  grep -Fq "$2" "$1" || fail "expected $2 in $1"
}

cat >"$TMP/hypr-rofi-lib" <<'SH'
hypr_rofi_dmenu() {
  printf '%s\n' "$HYPR_TEST_CHOICE"
}
SH

make_stub() {
  cat >"$TMP/bin/$1" <<'SH'
#!/usr/bin/env bash
printf '%s %s\n' "$(basename "$0")" "$*" >>"$CALLS"
SH
  chmod +x "$TMP/bin/$1"
}

run_menu() {
  HYPR_TEST_CHOICE="$1" \
    HYPR_ROFI_LIB="$TMP/hypr-rofi-lib" \
    HYPR_BIN_DIR="$TMP/bin" \
    PATH="$TMP/bin:$PATH" \
    CALLS="$CALLS" \
    bash "$2"
}

mkdir -p "$TMP/bin"
for command in hypr-tools-menu hypr-rofi-clipboard hypr-transition-menu kitty hypr-wallpaper hypr-keybindings-help; do
  make_stub "$command"
done

run_menu '󰒓 Tools' "$BIN/hypr-main-menu"
assert_contains "$CALLS" 'hypr-tools-menu '

run_menu ' Clipboard' "$BIN/hypr-tools-menu"
assert_contains "$CALLS" 'hypr-rofi-clipboard '

run_menu '󰹹 Transitions' "$BIN/hypr-tweaks-menu"
assert_contains "$CALLS" 'hypr-transition-menu '

run_menu '󰖩 WiFi' "$BIN/hypr-devices-menu"
assert_contains "$CALLS" 'kitty -e nmtui'

run_menu '󰌌 Keybindings help' "$BIN/hypr-help-menu"
assert_contains "$CALLS" 'hypr-keybindings-help '

echo "hypr menu categories test passed"
