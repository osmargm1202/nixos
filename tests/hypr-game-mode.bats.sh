#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT/dotfiles/config/profiles/hyprland"
HELPER="$PROFILE/.local/bin/hypr-game-mode"
LOOK="$PROFILE/.config/hypr/lua/look-and-feel.lua"
RULES="$PROFILE/.config/hypr/lua/windows-workspaces.lua"
MODULE="$PROFILE/.config/hypr/lua/game-mode.lua"

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

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
cat >"$tmp/bin/hyprctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${HYPRCTL_LOG:?}"
EOF
cat >"$tmp/bin/pgrep" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$tmp/bin/hyprctl" "$tmp/bin/pgrep"
export HYPRCTL_LOG="$tmp/hyprctl.log"

XDG_STATE_HOME="$tmp/state" PATH="$tmp/bin:$PATH" "$HELPER" toggle
[[ "$(XDG_STATE_HOME="$tmp/state" PATH="$tmp/bin:$PATH" "$HELPER" status)" == activated ]] ||
  fail 'game mode must activate on first toggle'
XDG_STATE_HOME="$tmp/state" PATH="$tmp/bin:$PATH" "$HELPER" waybar | jq -e '.class == "deactivated" and .text == "󰊴"' >/dev/null ||
  fail 'game mode Waybar state must invert the active indicator'
grep -Fxq 'reload' "$HYPRCTL_LOG" || fail 'game mode activation must reload Hyprland'

XDG_STATE_HOME="$tmp/state" PATH="$tmp/bin:$PATH" "$HELPER" toggle
[[ "$(XDG_STATE_HOME="$tmp/state" PATH="$tmp/bin:$PATH" "$HELPER" status)" == deactivated ]] ||
  fail 'game mode must deactivate on second toggle'
XDG_STATE_HOME="$tmp/state" PATH="$tmp/bin:$PATH" "$HELPER" waybar | jq -e '.class == "activated"' >/dev/null ||
  fail 'normal visual mode must activate the Waybar indicator'

printf '%s\n' 'PASS: Hyprland game mode disables visual effects on demand'
