#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-idle-inhibit"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[[ -x "$HELPER" ]] || fail 'i3 idle inhibitor missing or not executable'
bash -n "$HELPER"
! grep -Eq 'playerctl|looking-glass|freerdp|:3389|:8006|ss -H' "$HELPER" ||
  fail 'only explicit caffeine may control the sleep inhibitor'

tmp="$(mktemp -d)"
helper_pid=''
cleanup() {
  [[ -z "$helper_pid" ]] || kill "$helper_pid" 2>/dev/null || true
  [[ -z "$helper_pid" ]] || wait "$helper_pid" 2>/dev/null || true
  rm -rf "$tmp"
}
trap cleanup EXIT

mkdir -p "$tmp/bin" "$tmp/state/i3"
: >"$tmp/inhibitor-calls"
cat >"$tmp/bin/systemd-inhibit" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$INHIBITOR_CALLS"
trap 'exit 0' INT TERM
while :; do sleep 1; done
STUB
chmod +x "$tmp/bin/systemd-inhibit"

XDG_STATE_HOME="$tmp/state" \
I3_IDLE_INHIBIT_INTERVAL=0.05 \
INHIBITOR_CALLS="$tmp/inhibitor-calls" \
PATH="$tmp/bin:$PATH" \
"$HELPER" &
helper_pid=$!

sleep 0.15
[[ ! -s "$tmp/inhibitor-calls" ]] ||
  fail 'inhibitor started while caffeine is off'

touch "$tmp/state/i3/caffeine"
for _ in $(seq 1 20); do
  [[ -s "$tmp/inhibitor-calls" ]] && break
  sleep 0.05
done
grep -Fq -- '--what=idle' "$tmp/inhibitor-calls" ||
  fail 'caffeine does not block automatic idle handling'
grep -Fq -- '--why=i3 caffeine mode' "$tmp/inhibitor-calls" ||
  fail 'inhibitor reason does not identify explicit caffeine mode'

printf 'PASS: only explicit i3 caffeine blocks automatic idle handling\n'
