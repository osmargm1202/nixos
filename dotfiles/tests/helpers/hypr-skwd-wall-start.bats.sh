#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/config/profiles/hyprland/.local/bin/hypr-skwd-wall-start"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/state"
CALLS="$TMP/calls"
export CALLS

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

cat >"$TMP/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
printf 'systemctl %s\n' "$*" >>"$CALLS"
[ "${SYSTEMCTL_FAIL:-0}" != 1 ]
EOF

cat >"$TMP/bin/skwd" <<'EOF'
#!/usr/bin/env bash
printf 'skwd' >>"$CALLS"
printf ' <%s>' "$@" >>"$CALLS"
printf '\n' >>"$CALLS"
if [ "$1 $2" = "wall list" ]; then
  count_file="${SKWD_TEST_STATE}/list-count"
  count="$(cat "$count_file" 2>/dev/null || printf 0)"
  count=$((count + 1))
  printf '%s\n' "$count" >"$count_file"
  if [ "${SKWD_LIST_ALWAYS_EMPTY:-0}" = 1 ] || [ "$count" -lt 2 ]; then
    printf '{"count":0,"wallpapers":[]}\n'
  else
    printf '{"count":2,"wallpapers":[{"type":"static"},{"type":"video"}]}\n'
  fi
fi
EOF

cat >"$TMP/bin/sleep" <<'EOF'
#!/usr/bin/env bash
printf 'sleep %s\n' "$*" >>"$CALLS"
EOF

chmod +x "$TMP/bin/systemctl" "$TMP/bin/skwd" "$TMP/bin/sleep"

[ -x "$SCRIPT" ] || fail "missing executable hypr-skwd-wall-start"

export SKWD_TEST_STATE="$TMP/state"
SYSTEMCTL_BIN="$TMP/bin/systemctl" \
SKWD_BIN="$TMP/bin/skwd" \
SLEEP_BIN="$TMP/bin/sleep" \
SKWD_START_ATTEMPTS=3 \
  "$SCRIPT"

grep -Fxq 'systemctl --user start skwd-daemon.service' "$CALLS" || fail "must start user daemon service"
[ "$(grep -c '^skwd <wall> <list>$' "$CALLS")" -eq 2 ] || fail "must wait until collection is populated"
grep -Fxq 'sleep 1' "$CALLS" || fail "must sleep between readiness attempts"
grep -Fxq 'skwd <wall> <random_start> <{"interval":1800,"types":["static"]}>' "$CALLS" || fail "must start static 1800-second rotation"

: >"$CALLS"
rm -f "$TMP/state/list-count"
if SKWD_LIST_ALWAYS_EMPTY=1 \
  SYSTEMCTL_BIN="$TMP/bin/systemctl" \
  SKWD_BIN="$TMP/bin/skwd" \
  SLEEP_BIN="$TMP/bin/sleep" \
  SKWD_START_ATTEMPTS=2 \
  "$SCRIPT" 2>"$TMP/not-ready.err"; then
  fail "empty collection must return nonzero"
fi
! grep -q '<random_start>' "$CALLS" || fail "must not rotate an empty collection"
grep -Fq 'static wallpaper collection not ready after 2 attempts' "$TMP/not-ready.err" || fail "must explain readiness timeout"

: >"$CALLS"
if SYSTEMCTL_FAIL=1 \
  SYSTEMCTL_BIN="$TMP/bin/systemctl" \
  SKWD_BIN="$TMP/bin/skwd" \
  SLEEP_BIN="$TMP/bin/sleep" \
  "$SCRIPT" 2>"$TMP/service.err"; then
  fail "service start failure must return nonzero"
fi
! grep -q '^skwd ' "$CALLS" || fail "must not call Skwd after service failure"
grep -Fq 'failed to start skwd-daemon.service' "$TMP/service.err" || fail "must explain service failure"

printf 'PASS: Skwd session bootstrap\n'
