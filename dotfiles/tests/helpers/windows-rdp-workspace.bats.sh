#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/config/shared/.local/bin/windows-rdp"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() {
  echo "FAIL: $*" >&2
  echo "--- calls ---" >&2
  cat "$TMP/calls" >&2 2>/dev/null || true
  echo "--- stdout ---" >&2
  cat "$TMP/out" >&2 2>/dev/null || true
  echo "--- stderr ---" >&2
  cat "$TMP/err" >&2 2>/dev/null || true
  exit 1
}

stub() {
  local name="$1" body="$2"
  printf '#!/usr/bin/bash\n%s\n' "$body" >"$TMP/$name"
  chmod +x "$TMP/$name"
}

: >"$TMP/calls"
mkdir -p "$TMP/home"

stub nc 'exit 0'
stub sleep 'echo sleep "$@" >>"$CALLS"; exit 0'
stub docker 'echo docker "$@" >>"$CALLS"; exit 0'
stub podman 'exit 127'
stub xfreerdp3 'echo xfreerdp3 "$@" >>"$CALLS"; exit 0'
stub hyprctl 'case "$1 $2" in
  "-j activeworkspace") printf "{\"id\":5,\"name\":\"5\"}\n" ;;
  "-j clients") printf "[{\"address\":\"0xabc\",\"class\":\"windows-rdp\",\"initialClass\":\"windows-rdp\"}]\n" ;;
  "dispatch movetoworkspacesilent") echo hyprctl "$@" >>"$CALLS" ;;
  *) echo hyprctl "$@" >>"$CALLS" ;;
esac'

PATH="$TMP:/usr/bin:/bin" CALLS="$TMP/calls" HOME="$TMP/home" XDG_CURRENT_DESKTOP= WAYLAND_DISPLAY=wayland-1 \
  bash "$SCRIPT" run >"$TMP/out" 2>"$TMP/err"

bash -n "$SCRIPT" || fail "syntax failed"
/usr/bin/sleep 0.2
grep -q 'xfreerdp3 /v:localhost:3389' "$TMP/calls" || fail "RDP did not launch"
grep -q 'hyprctl dispatch movetoworkspacesilent 5,address:0xabc' "$TMP/calls" || fail "window was not moved to captured active workspace"

echo "windows-rdp workspace placement test passed"
