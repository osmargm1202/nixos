#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-idle-inhibit"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[ -x "$HELPER" ] || fail 'i3 idle inhibitor missing or not executable'
bash -n "$HELPER"

tmp="$(mktemp -d)"
helper_pid=''
stop_helper() {
  if [[ -n "$helper_pid" ]]; then
    kill "$helper_pid" 2>/dev/null || true
    wait "$helper_pid" 2>/dev/null || true
    helper_pid=''
  fi
}
cleanup() {
  stop_helper
  rm -rf "$tmp"
}
trap cleanup EXIT

mkdir -p "$tmp/bin" "$tmp/state/i3"
: >"$tmp/player-status"
: >"$tmp/inhibitor-calls"
: >"$tmp/xset-calls"
cat >"$tmp/bin/playerctl" <<'STUB'
#!/usr/bin/env bash
cat "$PLAYER_STATUS"
STUB
cat >"$tmp/bin/systemd-inhibit" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$INHIBITOR_CALLS"
trap 'exit 0' INT TERM
while :; do sleep 1; done
STUB
cat >"$tmp/bin/xset" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$XSET_CALLS"
STUB
cat >"$tmp/bin/pgrep" <<'STUB'
#!/usr/bin/env bash
case "$*" in
  *looking-glass-client*) exit "${MOCK_LOOKING_GLASS_VIEWER:-1}" ;;
  *wlfreerdp*) exit "${MOCK_RDP_VIEWER:-1}" ;;
  *) exit 1 ;;
esac
STUB
cat >"$tmp/bin/ss" <<'STUB'
#!/usr/bin/env bash
exit 1
STUB
chmod +x "$tmp/bin/playerctl" "$tmp/bin/systemd-inhibit" "$tmp/bin/xset" "$tmp/bin/pgrep" "$tmp/bin/ss"

start_helper() {
  XDG_STATE_HOME="$tmp/state" \
  I3_IDLE_INHIBIT_INTERVAL=0.05 \
  INHIBITOR_CALLS="$tmp/inhibitor-calls" \
  PLAYER_STATUS="$tmp/player-status" \
  XSET_CALLS="$tmp/xset-calls" \
  MOCK_RDP_VIEWER="${MOCK_RDP_VIEWER:-1}" \
  MOCK_LOOKING_GLASS_VIEWER="${MOCK_LOOKING_GLASS_VIEWER:-1}" \
  PATH="$tmp/bin:$PATH" \
  "$HELPER" &
  helper_pid=$!
}

wait_for_inhibition() {
  for _ in $(seq 1 20); do
    [[ -s "$tmp/inhibitor-calls" && -s "$tmp/xset-calls" ]] && return
    sleep 0.05
  done
  fail 'inhibitor did not start'
}

touch "$tmp/state/i3/caffeine"
start_helper
wait_for_inhibition
grep -Fq -- '--what=idle:sleep' "$tmp/inhibitor-calls" || fail 'caffeine does not block idle sleep'
grep -Fxq 's off' "$tmp/xset-calls" || fail 'caffeine does not disable the X screen saver'
grep -Fxq -- '-dpms' "$tmp/xset-calls" || fail 'caffeine does not disable DPMS'
stop_helper

rm "$tmp/state/i3/caffeine"
: >"$tmp/inhibitor-calls"
: >"$tmp/xset-calls"
printf 'Playing\n' >"$tmp/player-status"
start_helper
wait_for_inhibition
grep -Fq -- '--what=idle:sleep' "$tmp/inhibitor-calls" || fail 'active media does not block idle sleep'
grep -Fxq 's reset' "$tmp/xset-calls" || fail 'active media does not reset the X idle timer'
stop_helper

: >"$tmp/player-status"
: >"$tmp/inhibitor-calls"
: >"$tmp/xset-calls"
MOCK_LOOKING_GLASS_VIEWER=0 start_helper
wait_for_inhibition
grep -Fq -- '--what=idle:sleep' "$tmp/inhibitor-calls" || fail 'Looking Glass does not block idle sleep'
grep -Fxq 's reset' "$tmp/xset-calls" || fail 'Looking Glass does not reset the X idle timer'
stop_helper

: >"$tmp/inhibitor-calls"
: >"$tmp/xset-calls"
MOCK_RDP_VIEWER=0 start_helper
wait_for_inhibition
grep -Fq -- '--what=idle:sleep' "$tmp/inhibitor-calls" || fail 'RDP does not block idle sleep'
grep -Fxq 's reset' "$tmp/xset-calls" || fail 'RDP does not reset the X idle timer'
printf 'PASS: i3 caffeine and MPRIS playback block locking and system sleep\n'
