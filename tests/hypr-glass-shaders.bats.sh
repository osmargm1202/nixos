#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT/dotfiles/config/profiles/hyprland"
LOOK="$PROFILE/.config/hypr/lua/look-and-feel.lua"
RULES="$PROFILE/.config/hypr/lua/windows-workspaces.lua"
MAIN_MENU="$PROFILE/.local/bin/hypr-main-menu"
SHADER_MENU="$PROFILE/.local/bin/hypr-shader-menu"
ROFI_LIB="$PROFILE/.local/bin/hypr-rofi-lib"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

# Hyprland's stock blur must stay disabled; HyprGlass owns the visual effect.
grep -Fq 'manage_window_blur = true' "$LOOK" || fail 'HyprGlass must manage blur on glassed windows'
grep -Fq 'enabled = false,' "$LOOK" || fail 'Hyprland decoration blur must stay disabled'
for layer in waybar rofi nwg-dock nwg-dock-hyprland; do
  grep -Fq "hg.layer(\"$layer\"" "$LOOK" || fail "HyprGlass layer missing: $layer"
done
grep -Fq 'default_preset = "glass"' "$LOOK" || fail 'HyprGlass must use the glass preset by default'
if grep -Fq 'preset = "subtle"' "$LOOK"; then
  fail 'HyprGlass layers must use the glass preset'
fi

# Every requested client has both a HyprGlass tag and an opening shader rule.
for matcher in \
  '^(kitty)$' \
  '^(chromium|Chromium)$' \
  '^(brave-browser|Brave-browser|brave-origin)$' \
  '^(opera|Opera)$' \
  '^(obsidian)$' \
  '^(com.obsproject.Studio|obs)$' \
  '^[Bb][Tt][Oo][Pp]$' \
  '^(discord|com.discordapp.Discord)$' \
  '^(libreoffice.*|LibreOffice.*)$' \
  '^(Code|code|code-oss|VSCodium)$' \
  '^(Blender|blender)$' \
  '^(org.gnome.Nautilus)$' \
  '^(thunar|Thunar)$' \
  '^(org.gnome.Calculator)$' \
  '^(pavucontrol)$'; do
  grep -Fq "$matcher" "$RULES" || fail "client effect missing: $matcher"
done
if grep -Fq '{ class = "^(firefox|Firefox)$", opacity = browser_opacity },' "$RULES" ||
  grep -Fq '{ match = { class = "^(firefox|Firefox)$" }, shader = "pixelate", duration_ms = 200 },' "$RULES"; then
  fail 'Firefox must not receive HyprGlass or opening shader effects'
fi
grep -Fq '+hyprglass_enabled' "$RULES" || fail 'daily applications must explicitly enable HyprGlass'
grep -Fq '+hyprglass_preset_glass' "$RULES" || fail 'daily applications must use the glass preset'
grep -Fq '+shader_transition_open:/etc/hyprwindowshade-shaders/open/' "$RULES" || fail 'daily applications must receive opening shaders'

# The top-level menu directly opens the program/window config and shader picker.
grep -Fq "'󰆧 Programas y ventanas'" "$MAIN_MENU" || fail 'main menu program/window entry missing'
grep -Fq 'hypr-config-editor" "lua/windows-workspaces.lua"' "$MAIN_MENU" || fail 'main menu must open window rules editor'
grep -Fq "'󰎔 Shaders de apertura'" "$MAIN_MENU" || fail 'main menu shader entry missing'

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/shaders"
touch "$tmp/shaders/morph.glsl"

cat >"$tmp/bin/rofi" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null
if [[ -n "${ROFI_OUTPUT:-}" ]]; then
  printf '%s\n' "$ROFI_OUTPUT"
  exit 0
fi
calls="${ROFI_CALLS:?}"
count="$(cat "$calls" 2>/dev/null || printf '0')"
count=$((count + 1))
printf '%s' "$count" >"$calls"
case "$count" in
  1) printf '%s\n' 'Assign shader to Firefox' ;;
  2) printf '%s\n' 'morph' ;;
esac
EOF
cat >"$tmp/bin/hyprctl" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == activewindow ]]; then
  printf '%s\n' '{"class":"Firefox"}'
else
  printf '%s\n' "$*" >>"${HYPRCTL_LOG:?}"
fi
EOF
cat >"$tmp/bin/jq" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null
printf '%s\n' Firefox
EOF
cat >"$tmp/bin/hypr-config-editor" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"${CONFIG_EDITOR_ARGS:?}"
EOF
cat >"$tmp/bin/hypr-shader-menu" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' called >"${SHADER_MENU_CALLED:?}"
EOF
chmod +x "$tmp/bin"/*

ROFI_CALLS="$tmp/rofi-calls" HYPRCTL_LOG="$tmp/hyprctl-log" \
  HOME="$tmp/home" PATH="$tmp/bin:$PATH" HYPR_ROFI_LIB="$ROFI_LIB" \
  HYPR_SHADER_ROOT="$tmp/shaders" XDG_STATE_HOME="$tmp/state" "$SHADER_MENU"
[[ "$(<"$tmp/state/hypr/shader-overrides")" == $'^Firefox$\tmorph' ]] ||
  fail 'shader picker must persist the focused application override'
grep -Fxq 'reload' "$tmp/hyprctl-log" || fail 'shader picker must reload Hyprland'

ROFI_OUTPUT='Programas y ventanas' CONFIG_EDITOR_ARGS="$tmp/config-editor-args" \
  HOME="$tmp/home" PATH="$tmp/bin:$PATH" HYPR_ROFI_LIB="$ROFI_LIB" \
  HYPR_BIN_DIR="$tmp/bin" "$MAIN_MENU"
[[ "$(<"$tmp/config-editor-args")" == 'lua/windows-workspaces.lua' ]] ||
  fail 'main menu must open the window rules editor directly'

printf 'PASS: HyprGlass surfaces, application shaders and manual menu controls are configured\n'
