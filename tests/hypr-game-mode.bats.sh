#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT/dotfiles/config/profiles/hyprland"
HELPER="$PROFILE/.local/bin/hypr-game-mode"
LOOK="$PROFILE/.config/hypr/lua/look-and-feel.lua"
RULES="$PROFILE/.config/hypr/lua/windows-workspaces.lua"
MODULE="$PROFILE/.config/hypr/lua/game-mode.lua"
AUTOSTART="$PROFILE/.config/hypr/lua/autostart.lua"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[[ -x "$HELPER" ]] || fail 'game mode helper must be executable'
[[ -f "$MODULE" ]] || fail 'game mode Lua module must exist'
grep -Fq 'gaps_in = game_mode and 0 or 12' "$LOOK" || fail 'game mode must remove inner gaps'
grep -Fq 'kill -s 43 "$pid"' "$HELPER" || fail 'game mode must refresh Waybar only after state changes'
grep -Fq 'gaps_out = game_mode and 0 or 12' "$LOOK" || fail 'game mode must remove outer gaps'
grep -Fq 'rounding = game_mode and 0 or 12' "$LOOK" || fail 'game mode must remove rounding'
grep -Fq 'enabled = visual_effects' "$LOOK" || fail 'game mode must disable visual effects'
grep -Fq 'blur = visual_effects' "$LOOK" || fail 'game mode must disable scroll overview blur'
grep -Fq 'if not game_mode then' "$RULES" || fail 'game mode must disable HyprGlass and opening shaders'
grep -Fxq '  "hypr-game-mode sync",' "$AUTOSTART" ||
  fail 'autostart must synchronize wallpaper with persisted game mode'
! grep -Fq '"hypr-wallpaper restore"' "$AUTOSTART" ||
  fail 'autostart must not restore wallpaper unconditionally'

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/home/.local/bin"
cat >"$tmp/bin/hyprctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${HYPRCTL_LOG:?}"
EOF
cat >"$tmp/bin/hypr-wallpaper" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$1" >>"${HYPR_WALLPAPER_LOG:?}"
if [[ "$1" == restore && -e "${HYPR_WALLPAPER_FAIL_RESTORE_FILE:-}" ]]; then
  exit 1
fi
EOF
cat >"$tmp/bin/pgrep" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$tmp/bin/hyprctl" "$tmp/bin/hypr-wallpaper" "$tmp/bin/pgrep"
ln -s "$tmp/bin/hypr-wallpaper" "$tmp/home/.local/bin/hypr-wallpaper"
export HOME="$tmp/home"
export HYPRCTL_LOG="$tmp/hyprctl.log"
export HYPR_WALLPAPER_LOG="$tmp/hypr-wallpaper.log"
export HYPR_WALLPAPER_FAIL_RESTORE_FILE="$tmp/fail-restore"

XDG_STATE_HOME="$tmp/state" PATH="$tmp/bin:$PATH" "$HELPER" toggle
[[ "$(XDG_STATE_HOME="$tmp/state" PATH="$tmp/bin:$PATH" "$HELPER" status)" == activated ]] ||
  fail 'game mode must activate on first toggle'
XDG_STATE_HOME="$tmp/state" PATH="$tmp/bin:$PATH" "$HELPER" waybar | jq -e '.class == "activated" and .text == "󰊴"' >/dev/null ||
  fail 'game mode Waybar state must activate the gamepad indicator'
grep -Fxq 'reload' "$HYPRCTL_LOG" || fail 'game mode activation must reload Hyprland'

[[ "$(paste -sd, "$HYPR_WALLPAPER_LOG")" == hide ]] ||
  fail 'game mode activation must hide wallpaper'
XDG_STATE_HOME="$tmp/state" PATH="$tmp/bin:$PATH" "$HELPER" toggle
[[ "$(XDG_STATE_HOME="$tmp/state" PATH="$tmp/bin:$PATH" "$HELPER" status)" == deactivated ]] ||
  fail 'game mode must deactivate on second toggle'
XDG_STATE_HOME="$tmp/state" PATH="$tmp/bin:$PATH" "$HELPER" waybar | jq -e '.class == "deactivated"' >/dev/null ||
  fail 'normal visual mode must deactivate the Waybar indicator'

[[ "$(paste -sd, "$HYPR_WALLPAPER_LOG")" == hide,restore ]] ||
  fail 'game mode deactivation must restore wallpaper'

reloads_before_sync="$(grep -Fc reload "$HYPRCTL_LOG")"
XDG_STATE_HOME="$tmp/state" PATH="$tmp/bin:$PATH" "$HELPER" sync
[[ "$(paste -sd, "$HYPR_WALLPAPER_LOG")" == hide,restore,restore ]] ||
  fail 'sync must restore the wallpaper for persisted normal mode'
[[ "$(grep -Fc reload "$HYPRCTL_LOG")" -eq "$reloads_before_sync" ]] ||
  fail 'sync must not reload Hyprland'

XDG_STATE_HOME="$tmp/state" PATH="$tmp/bin:$PATH" "$HELPER" on
touch "$HYPR_WALLPAPER_FAIL_RESTORE_FILE"
if XDG_STATE_HOME="$tmp/state" PATH="$tmp/bin:$PATH" "$HELPER" off; then
  fail 'game mode deactivation must fail when wallpaper restore fails'
fi
rm "$HYPR_WALLPAPER_FAIL_RESTORE_FILE"
[[ "$(XDG_STATE_HOME="$tmp/state" PATH="$tmp/bin:$PATH" "$HELPER" status)" == activated ]] ||
  fail 'failed wallpaper restore must preserve game mode activation'
[[ "$(tail -n 2 "$HYPR_WALLPAPER_LOG")" == $'restore\nhide' ]] ||
  fail 'failed wallpaper restore must re-hide wallpaper during rollback'
printf '%s\n' 'PASS: Hyprland game mode disables visual effects on demand'
