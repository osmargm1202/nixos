#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-hotkeys"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
config="$tmp/config"
cat >"$config" <<'EOF'
set $mod Mod4
bindsym $mod+Return exec terminal
include "config.d/*.conf"
mode "resize" {
  bindsym h resize shrink width 10 px or 10 ppt
  bindsym Escape mode "default"
}
EOF
mkdir -p "$tmp/bin" "$tmp/config.d"
cat >"$tmp/config.d/90-user.conf" <<'EOF'
bindsym $mod+Escape exec firefox-tabs
include ../config
EOF
cat >"$tmp/bin/i3-rofi" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$I3_ROFI_ARGS"
cat >"$I3_ROFI_MENU"
EOF
chmod +x "$tmp/bin/i3-rofi"

I3_CONFIG_FILE="$config" I3_ROFI_ARGS="$tmp/args" I3_ROFI_MENU="$tmp/menu" \
  PATH="$tmp/bin:$PATH" "$HELPER"

[[ "$(<"$tmp/args")" == 'Atajos 20' ]] || fail 'hotkey menu title or size is incorrect'
grep -Eq '^\$mod\+Return[[:space:]]+exec terminal$' "$tmp/menu" ||
  fail 'top-level binding was not rendered'
grep -Eq '^h[[:space:]]+resize shrink width 10 px or 10 ppt$' "$tmp/menu" ||
  fail 'indented mode binding was not rendered'
grep -Eq '^Escape[[:space:]]+mode "default"$' "$tmp/menu" ||
  fail 'mode exit binding was not rendered'

grep -Eq '^\$mod\+Escape[[:space:]]+exec firefox-tabs$' "$tmp/menu" ||
  fail 'user bindings from included configuration were not rendered'
[[ "$(grep -Fc 'exec firefox-tabs' "$tmp/menu")" == 1 ]] ||
  fail 'recursive include duplicated bindings'
printf 'PASS: i3 hotkey menu renders shared, user and mode bindings\n'
