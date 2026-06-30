#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/config/shared/.local/bin/hypr-config-editor"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

HYPR_ROOT="$TMP/dotfiles/config/shared/.config/hypr"
mkdir -p "$HYPR_ROOT/lua" "$TMP/bin"
printf 'input config\n' >"$HYPR_ROOT/lua/input.lua"
printf 'main lua config\n' >"$HYPR_ROOT/hyprland.lua"
printf 'legacy conf config\n' >"$HYPR_ROOT/hyprland.conf"

cat >"$TMP/lib.sh" <<'SH'
#!/usr/bin/env bash
hypr_rofi_dmenu() {
  local prompt="$1"
  local choice
  IFS= read -r choice <"$ROFI_RESPONSES"
  tail -n +2 "$ROFI_RESPONSES" >"$ROFI_RESPONSES.tmp"
  mv "$ROFI_RESPONSES.tmp" "$ROFI_RESPONSES"
  printf '%s\n' "$prompt" >>"$ROFI_PROMPTS"
  cat >>"$ROFI_INPUTS"
  printf '%s\n' "$choice"
}
HYPR_ROFI_WIDTH=600px
SH

cat >"$TMP/bin/kitty" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$KITTY_ARGS"
SH
chmod +x "$TMP/bin/kitty"

cat >"$TMP/bin/xdg-open" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$XDG_OPEN_ARGS"
SH
chmod +x "$TMP/bin/xdg-open"

cat >"$TMP/bin/orgm-dot" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$ORGM_DOT_ARGS"
SH
chmod +x "$TMP/bin/orgm-dot"

run_editor() {
  : >"$TMP/prompts"
  : >"$TMP/inputs"
  : >"$TMP/kitty.args"
  : >"$TMP/xdg-open.args"
  : >"$TMP/orgm-dot.args"
  PATH="$TMP/bin:$PATH" \
  HYPR_ROFI_LIB="$TMP/lib.sh" \
  HYPR_CONFIG_EDITOR_ROOT="$HYPR_ROOT" \
  ROFI_RESPONSES="$TMP/responses" \
  ROFI_PROMPTS="$TMP/prompts" \
  ROFI_INPUTS="$TMP/inputs" \
  KITTY_ARGS="$TMP/kitty.args" \
  XDG_OPEN_ARGS="$TMP/xdg-open.args" \
  ORGM_DOT_ARGS="$TMP/orgm-dot.args" \
  "$SCRIPT"
}

printf 'lua/input.lua\nEditar con nvim\n' >"$TMP/responses"
run_editor

grep -Fxq 'Hypr Lua config' "$TMP/prompts" || {
  echo 'FAIL: first prompt should list Hypr Lua config files' >&2
  cat "$TMP/prompts" >&2
  exit 1
}
grep -Fxq 'lua/input.lua' "$TMP/inputs" || {
  echo 'FAIL: config list should include Lua config files' >&2
  cat "$TMP/inputs" >&2
  exit 1
}
if grep -Fxq 'hyprland.conf' "$TMP/inputs"; then
  echo 'FAIL: config list should not include legacy .conf files' >&2
  cat "$TMP/inputs" >&2
  exit 1
fi
grep -Fxq -- "--class hypr-config-editor -e fish -lc nvim \"\$argv[1]\" -- $HYPR_ROOT/lua/input.lua" "$TMP/kitty.args" || {
  echo 'FAIL: nvim option should open selected file through fish so the distrobox nvim wrapper is available' >&2
  cat "$TMP/kitty.args" >&2
  exit 1
}
grep -Fxq -- 'sync .config/hypr/lua/input.lua' "$TMP/orgm-dot.args" || {
  echo 'FAIL: nvim option should sync only selected managed file' >&2
  cat "$TMP/orgm-dot.args" >&2
  exit 1
}

printf 'hyprland.lua\nAbrir con app por defecto\n' >"$TMP/responses"
run_editor

grep -Fxq -- "$HYPR_ROOT/hyprland.lua" "$TMP/xdg-open.args" || {
  echo 'FAIL: default-app option should call xdg-open with selected Lua file' >&2
  cat "$TMP/xdg-open.args" >&2
  exit 1
}
if grep -Fxq 'Sincronizar Hypr config' "$TMP/prompts"; then
  echo 'FAIL: default-app option should not ask before syncing' >&2
  cat "$TMP/prompts" >&2
  exit 1
fi
grep -Fxq -- 'sync .config/hypr/hyprland.lua' "$TMP/orgm-dot.args" || {
  echo 'FAIL: default-app option should sync only selected managed Lua file automatically' >&2
  cat "$TMP/orgm-dot.args" >&2
  exit 1
}

echo 'hypr config editor test passed'
