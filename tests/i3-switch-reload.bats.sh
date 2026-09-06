#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-reload-after-switch"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[[ -x "$HELPER" ]] || fail 'i3 reload helper missing or not executable'
grep -Fq '${XDG_RUNTIME_DIR:-/run/user/$(id -u)}' "$HELPER" ||
  fail 'helper cannot discover runtime directory without DISPLAY'
grep -Fq '[ -S "$socket" ]' "$HELPER" || fail 'helper does not require a real IPC socket'
grep -Fq -- '-t get_version' "$HELPER" || fail 'helper does not validate live i3 socket'
grep -Fq 'i3-msg -s "$socket" reload' "$HELPER" || fail 'helper does not reload i3'
if grep -Fq 'DISPLAY' "$HELPER"; then fail 'helper incorrectly requires DISPLAY'; fi
if grep -Eq 'i3-msg .*restart|hyprctl' "$HELPER"; then
  fail 'switch recovery restarts a compositor instead of safely reloading i3'
fi

bash -n "$HELPER"
tmp="$(mktemp -d)"
cleanup() {
  [[ -z "${socket_server_a:-}" ]] || kill "$socket_server_a" 2>/dev/null || true
  [[ -z "${socket_server_b:-}" ]] || kill "$socket_server_b" 2>/dev/null || true
  rm -rf "$tmp"
}
trap cleanup EXIT
mkdir -p "$tmp/bin" "$tmp/runtime/i3"
cat >"$tmp/bin/i3-msg" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$I3_MSG_CALLS"
if [[ "$*" == *' reload' && ( "${I3_FAIL_ALL:-0}" == 1 || "$*" == *'ipc-socket.a'* ) ]]; then
  exit 7
fi
exit 0
STUB
chmod +x "$tmp/bin/i3-msg"
nc -d -lUk "$tmp/runtime/i3/ipc-socket.a" &
socket_server_a=$!
nc -d -lUk "$tmp/runtime/i3/ipc-socket.b" &
socket_server_b=$!
for _ in {1..30}; do
  [[ -S "$tmp/runtime/i3/ipc-socket.a" && -S "$tmp/runtime/i3/ipc-socket.b" ]] && break
  sleep 0.05
done
[[ -S "$tmp/runtime/i3/ipc-socket.a" && -S "$tmp/runtime/i3/ipc-socket.b" ]] ||
  fail 'socket fixture failed'

export I3_MSG_CALLS="$tmp/calls"
env -u DISPLAY -u I3SOCK XDG_RUNTIME_DIR="$tmp/runtime" PATH="$tmp/bin:$PATH" "$HELPER"
grep -Fq -- '-s '"$tmp/runtime/i3/ipc-socket.a"' -t get_version' "$tmp/calls" ||
  fail 'first socket was not validated'
grep -Fq -- '-s '"$tmp/runtime/i3/ipc-socket.a"' reload' "$tmp/calls" ||
  fail 'first live socket was not reloaded'
grep -Fq -- '-s '"$tmp/runtime/i3/ipc-socket.b"' reload' "$tmp/calls" ||
  fail 'helper stopped after first reload failure'

if I3_FAIL_ALL=1 env -u DISPLAY -u I3SOCK XDG_RUNTIME_DIR="$tmp/runtime" \
  PATH="$tmp/bin:$PATH" "$HELPER" 2>"$tmp/error"; then
  fail 'helper reported success after every live reload failed'
fi
grep -Fq 'failed to reload every live i3 IPC socket' "$tmp/error" ||
  fail 'all-reloads-failed warning missing'

printf 'PASS: Home Manager safely reloads only live i3 after linking updated config\n'
