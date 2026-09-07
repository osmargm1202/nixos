#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER="$ROOT/dotfiles/config/profiles/hyprland/.local/bin/hypr-game-mode"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[[ -x "$HELPER" ]] || fail 'game mode helper must be executable'

tmp="$(mktemp -d)"
cleanup() {
  if [[ -f "$tmp/background-pids" ]]; then
    while IFS= read -r pid; do
      kill "$pid" 2>/dev/null || true
    done <"$tmp/background-pids"
  fi
  rm -rf "$tmp"
}
trap cleanup EXIT
mkdir -p "$tmp/bin" "$tmp/home"
cat >"$tmp/bin/hyprctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${HYPRCTL_LOG:?}"
exit 0
EOF
cat >"$tmp/bin/hypr-wallpaper" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$1" >>"${HYPR_WALLPAPER_LOG:?}"
if [[ "$1" == restore && -e "${HYPR_WALLPAPER_FAIL_RESTORE_FILE:-}" ]]; then
  exit 1
fi
if [[ "$1" == restore ]]; then
  sleep 60 >/dev/null 2>&1 &
  printf '%s\n' "$!" >>"${BACKGROUND_PIDS:?}"
fi
EOF
cat >"$tmp/bin/pgrep" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
cat >"$tmp/bin/notify-send" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$tmp/bin/hyprctl" "$tmp/bin/hypr-wallpaper" "$tmp/bin/pgrep" "$tmp/bin/notify-send"
export HOME="$tmp/home"
export HYPRCTL_LOG="$tmp/hyprctl.log"
export HYPR_WALLPAPER_LOG="$tmp/hypr-wallpaper.log"
export HYPR_WALLPAPER_FAIL_RESTORE_FILE="$tmp/fail-restore"
export HYPR_WALLPAPER_BIN="$tmp/bin/hypr-wallpaper"
export BACKGROUND_PIDS="$tmp/background-pids"

XDG_STATE_HOME="$tmp/state" PATH="$tmp/bin:$PATH" "$HELPER" toggle
[[ "$(XDG_STATE_HOME="$tmp/state" PATH="$tmp/bin:$PATH" "$HELPER" status)" == activated ]] ||
  fail 'game mode must activate on first toggle'
XDG_STATE_HOME="$tmp/state" PATH="$tmp/bin:$PATH" "$HELPER" waybar | jq -e '.class == "activated"' >/dev/null ||
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

# Restoring a wallpaper starts a long-lived child. A subsequent transaction
# must finish while that child remains alive, not wait for its inherited lock.
read -r background_pid <"$BACKGROUND_PIDS"
kill -0 "$background_pid"
XDG_STATE_HOME="$tmp/state" PATH="$tmp/bin:$PATH" timeout 3s "$HELPER" sync ||
  fail 'wallpaper child must not retain the game-mode transaction lock'
[[ "$(paste -sd, "$HYPR_WALLPAPER_LOG")" == hide,restore,restore ]] ||
  fail 'sync must restore wallpaper in normal mode'
[[ "$(grep -Fc reload "$HYPRCTL_LOG")" -eq "$reloads_before_sync" ]] ||
  fail 'sync must not reload Hyprland'
kill -0 "$background_pid"

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
printf '%s\n' 'PASS: game mode transitions, rollback and lock release'
