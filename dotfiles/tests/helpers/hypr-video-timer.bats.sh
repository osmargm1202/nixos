#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NIXOS_ROOT="$(cd "$ROOT/.." && pwd)"
SCRIPT="$ROOT/config/shared/.local/bin/hypr-video-timer"
TMP="$(mktemp -d)"
REAL_SLEEP="$(command -v sleep)"
REAL_KILL="$(type -P kill)"
cleanup() {
  local pid
  while read -r pid; do
    builtin kill "$pid" 2>/dev/null || true
  done < <(jobs -pr)
  wait 2>/dev/null || true
  rm -rf "$TMP"
}
trap cleanup EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

kill() {
  "$FAKE_KILL" "$@"
}
export -f kill

proc_starttime() {
  local pid="$1"
  local stat rest
  local -a fields

  stat="$(<"/proc/$pid/stat")"
  rest="${stat##*) }"
  read -r -a fields <<< "$rest"
  printf '%s\n' "${fields[19]}"
}

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
  builtin kill "$pid" 2>/dev/null || true
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
[[ "${NOTIFY_FAIL:-0}" == 0 ]]
STUB
cat > "$TMP/bin/kill" <<'STUB'
#!/usr/bin/env bash
printf 'kill %s\n' "$*" >> "$CALLS"
if [[ "${DELAY_KILL:-0}" == 1 && "${1:-}" != -0 ]]; then
  : > "$KILL_ENTERED"
  for _ in {1..100}; do
    [[ ! -e "$KILL_RELEASE" ]] || break
    "$REAL_SLEEP" 0.02
  done
  [[ -e "$KILL_RELEASE" ]] || exit 124
fi
exec "$REAL_KILL" "$@"
STUB
chmod +x "$TMP/bin/"*

run_timer() {
  env CALLS="$CALLS" PATH="$TMP/bin:$PATH" XDG_RUNTIME_DIR="$TMP/runtime" \
    REAL_SLEEP="$REAL_SLEEP" REAL_KILL="$REAL_KILL" FAKE_KILL="$TMP/bin/kill" \
    KILL_ENTERED="$TMP/kill-entered" KILL_RELEASE="$TMP/kill-release" \
    ROFI_INPUT="${ROFI_INPUT:-}" ROFI_CANCEL="${ROFI_CANCEL:-0}" \
    PLAYERCTL_FAIL="${PLAYERCTL_FAIL:-0}" NOTIFY_FAIL="${NOTIFY_FAIL:-0}" \
    BLOCK_SLEEP="${BLOCK_SLEEP:-0}" DELAY_KILL="${DELAY_KILL:-0}" \
    "$SCRIPT"
}

CALLS="$TMP/cancel.calls"
ROFI_CANCEL=1 run_timer
[[ ! -s "$CALLS" ]] || fail "cancelled input caused side effects"

CALLS="$TMP/invalid.calls"
ROFI_CANCEL=0
for invalid in '' 0 abc -1 1.5; do
  ROFI_INPUT="$invalid" run_timer
 done
[[ ! -s "$CALLS" ]] || fail "invalid input caused side effects"

CALLS="$TMP/stale-unrelated.calls"
mkdir -p "$TMP/runtime/hypr-video-timer-$UID"
env HYPR_VIDEO_TIMER_TOKEN=unrelated-token bash -c \
  'while :; do "$1" 0.05; done' hypr-video-timer-unrelated "$REAL_SLEEP" &
unrelated=$!
unrelated_starttime="$(proc_starttime "$unrelated")"
printf '%s %s %s\n' "$unrelated" "$unrelated_starttime" stale-token \
  > "$TMP/runtime/hypr-video-timer-$UID/state"
ROFI_INPUT=1 run_timer
builtin kill -0 "$unrelated" 2>/dev/null || fail "stale state signalled unrelated live process"
! grep -q "^kill $unrelated$" "$CALLS" || fail "stale state attempted to signal unrelated live process"
builtin kill "$unrelated" 2>/dev/null || true
wait_for_exit "$unrelated" || fail "unrelated test process did not exit within 2 seconds"

CALLS="$TMP/valid.calls"
ROFI_INPUT=5 run_timer
expected=$'hyprctl dispatch workspace previous\nplayerctl play\nsleep 5\nhyprctl dispatch workspace previous'
[[ "$(cat "$CALLS")" == "$expected" ]] || fail "valid timer call order differs: $(cat "$CALLS")"

CALLS="$TMP/player-failure.calls"
PLAYERCTL_FAIL=1 NOTIFY_FAIL=1 ROFI_INPUT=5 run_timer
[[ "$(grep -c '^hyprctl dispatch workspace previous$' "$CALLS")" -eq 2 ]] || fail "playerctl and notification failure skipped final switch"
grep -q '^notify-send ' "$CALLS" || fail "playerctl failure did not attempt notification"
PLAYERCTL_FAIL=0 NOTIFY_FAIL=0

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
grep -q '^kill ' "$CALLS" || fail "replacement did not use fake kill behavior"

CALLS="$TMP/cleanup-transfer-race.calls"
rm -f "$TMP/kill-entered" "$TMP/kill-release"
BLOCK_SLEEP=1 ROFI_INPUT=30 run_timer &
incumbent=$!
for _ in {1..100}; do
  [[ -f "$TMP/runtime/hypr-video-timer-$UID/state" ]] && break
  "$REAL_SLEEP" 0.02
done
[[ -f "$TMP/runtime/hypr-video-timer-$UID/state" ]] || fail "race incumbent did not publish state"
read -r incumbent_owner _ < "$TMP/runtime/hypr-video-timer-$UID/state"

DELAY_KILL=1 BLOCK_SLEEP=1 ROFI_INPUT=30 run_timer &
replacement=$!
for _ in {1..100}; do
  [[ -e "$TMP/kill-entered" ]] && break
  "$REAL_SLEEP" 0.02
done
[[ -e "$TMP/kill-entered" ]] || fail "replacement did not reach delayed signal"
read -r replacement_owner _ < "$TMP/runtime/hypr-video-timer-$UID/state"
[[ "$replacement_owner" != "$incumbent_owner" ]] || fail "ownership was not transferred before signalling incumbent"

builtin kill "$incumbent_owner" 2>/dev/null || true
"$REAL_SLEEP" 0.05
read -r owner_during_cleanup _ < "$TMP/runtime/hypr-video-timer-$UID/state"
[[ "$owner_during_cleanup" == "$replacement_owner" ]] || fail "incumbent cleanup deleted replacement state"
: > "$TMP/kill-release"
wait_for_exit "$incumbent" || fail "race incumbent did not exit within 2 seconds"
read -r owner_after_cleanup _ < "$TMP/runtime/hypr-video-timer-$UID/state"
[[ "$owner_after_cleanup" == "$replacement_owner" ]] || fail "incumbent cleanup removed replacement ownership"

builtin kill "$replacement_owner" 2>/dev/null || true
wait_for_exit "$replacement" || fail "race replacement did not exit within 2 seconds"
[[ ! -e "$TMP/runtime/hypr-video-timer-$UID/state" ]] || fail "race replacement state was not cleaned"

[[ "$(grep -c '"\.local/bin/hypr-video-timer"' "$NIXOS_ROOT/nixos/common-dotfiles.nix")" -eq 2 ]] \
  || fail "common-dotfiles.nix does not export helper for both Hyprland profiles"

echo "hypr video timer tests passed"
