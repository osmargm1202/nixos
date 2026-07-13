#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/config/shared/.local/bin/hypr-video-timer"
TMP="$(mktemp -d)"
REAL_SLEEP="$(command -v sleep)"
trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

wait_for_exit() {
  local pid="$1"
  local state

  for _ in {1..100}; do
    if [[ ! -e "/proc/$pid/stat" ]]; then
      wait "$pid" 2>/dev/null || true
      return 0
    fi
    state="$(awk '{print $3}' "/proc/$pid/stat" 2>/dev/null || true)"
    if [[ "$state" == Z ]]; then
      wait "$pid" 2>/dev/null || true
      return 0
    fi
    "$REAL_SLEEP" 0.02
  done

  pkill -TERM -P "$pid" 2>/dev/null || true
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  return 1
}

mkdir -p "$TMP/bin" "$TMP/runtime"

cat > "$TMP/bin/rofi" <<'STUB'
#!/usr/bin/env bash
[[ "${ROFI_CANCEL:-0}" == 0 ]] || exit 1
printf '%s\n' "${ROFI_INPUT:-}"
STUB
cat > "$TMP/bin/hyprctl" <<'STUB'
#!/usr/bin/env bash
printf 'hyprctl %s\n' "$*" >> "$CALLS"
STUB
cat > "$TMP/bin/playerctl" <<'STUB'
#!/usr/bin/env bash
printf 'playerctl %s\n' "$*" >> "$CALLS"
[[ "${PLAYERCTL_FAIL:-0}" == 0 ]]
STUB
cat > "$TMP/bin/sleep" <<'STUB'
#!/usr/bin/env bash
printf 'sleep %s\n' "$*" >> "$CALLS"
if [[ "${BLOCK_SLEEP:-0}" == 1 ]]; then
  while :; do "$REAL_SLEEP" 0.05; done
fi
STUB
cat > "$TMP/bin/notify-send" <<'STUB'
#!/usr/bin/env bash
printf 'notify-send %s\n' "$*" >> "$CALLS"
STUB
chmod +x "$TMP/bin/"*

run_timer() {
  env CALLS="$CALLS" PATH="$TMP/bin:$PATH" XDG_RUNTIME_DIR="$TMP/runtime" \
    REAL_SLEEP="$REAL_SLEEP" \
    ROFI_INPUT="${ROFI_INPUT:-}" ROFI_CANCEL="${ROFI_CANCEL:-0}" \
    PLAYERCTL_FAIL="${PLAYERCTL_FAIL:-0}" BLOCK_SLEEP="${BLOCK_SLEEP:-0}" \
    "$SCRIPT"
}

CALLS="$TMP/cancel.calls"
ROFI_CANCEL=1 run_timer
[[ ! -s "$CALLS" ]] || fail "cancelled input caused side effects"

CALLS="$TMP/invalid.calls"
ROFI_CANCEL=0 ROFI_INPUT=0 run_timer
ROFI_INPUT=abc run_timer
[[ ! -s "$CALLS" ]] || fail "invalid input caused side effects"

CALLS="$TMP/valid.calls"
ROFI_INPUT=5 run_timer
expected=$'hyprctl dispatch workspace previous\nplayerctl play\nsleep 5\nhyprctl dispatch workspace previous'
[[ "$(cat "$CALLS")" == "$expected" ]] || fail "valid timer call order differs: $(cat "$CALLS")"

CALLS="$TMP/player-failure.calls"
PLAYERCTL_FAIL=1 ROFI_INPUT=5 run_timer
[[ "$(grep -c '^hyprctl dispatch workspace previous$' "$CALLS")" -eq 2 ]] || fail "playerctl failure skipped final switch"
grep -q '^notify-send ' "$CALLS" || fail "playerctl failure did not notify"
PLAYERCTL_FAIL=0

CALLS="$TMP/replace.calls"
BLOCK_SLEEP=1 ROFI_INPUT=30 run_timer &
first=$!
for _ in {1..100}; do
  if [[ -f "$TMP/runtime/hypr-video-timer-$UID/state" ]] \
    && grep -q '^sleep 30$' "$CALLS" 2>/dev/null; then
    break
  fi
  "$REAL_SLEEP" 0.02
done
[[ -f "$TMP/runtime/hypr-video-timer-$UID/state" ]] || fail "first invocation did not publish state"
grep -q '^sleep 30$' "$CALLS" || fail "first invocation did not enter sleep"
BLOCK_SLEEP=0 ROFI_INPUT=1 run_timer
wait_for_exit "$first" || fail "replaced invocation did not exit within 2 seconds"
[[ "$(grep -c '^hyprctl dispatch workspace previous$' "$CALLS")" -eq 3 ]] || fail "replaced invocation returned to stale workspace"
[[ ! -e "$TMP/runtime/hypr-video-timer-$UID/state" ]] || fail "owned state was not cleaned"
[[ "$(stat -c %a "$TMP/runtime/hypr-video-timer-$UID")" == 700 ]] || fail "runtime directory mode is not 700"

grep -q '"\.local/bin/hypr-video-timer"' "$ROOT/config/dotfiles.json" || fail "dotfiles.json does not export helper"

echo "hypr video timer tests passed"
