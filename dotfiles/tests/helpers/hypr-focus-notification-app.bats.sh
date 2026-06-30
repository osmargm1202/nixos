#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/config/shared/.local/bin/hypr-focus-notification-app"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

CALLS="$TMP/calls.log"
mkdir -p "$TMP/bin"

cat >"$TMP/bin/hyprctl" <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = "-j" ] && [ "${2:-}" = "clients" ]; then
  cat <<'JSON'
[
  {"address":"0xdota","pid":570,"class":"steam_app_570","initialClass":"steam_app_570","title":"Dota 2"},
  {"address":"0/chrome","pid":999,"class":"chromium","initialClass":"chromium","title":"WhatsApp - Chromium"}
]
JSON
  exit 0
fi
printf '%s\n' "$*" >>"$CALLS"
SH
chmod +x "$TMP/bin/hyprctl"

PATH="$TMP/bin:$PATH" CALLS="$CALLS" SWAYNC_APP_NAME="Dota 2" "$SCRIPT"

grep -q 'address:0xdota' "$CALLS" || {
  echo "FAIL: Dota notification did not focus steam_app_570" >&2
  cat "$CALLS" >&2 || true
  exit 1
}

: >"$CALLS"
PATH="$TMP/bin:$PATH" CALLS="$CALLS" SWAYNC_HINT_PID="999" SWAYNC_APP_NAME="Pi" "$SCRIPT"
grep -q 'address:0/chrome' "$CALLS" || {
  echo "FAIL: generic pid hint did not focus exact window pid 999" >&2
  cat "$CALLS" >&2 || true
  exit 1
}

: >"$CALLS"
PATH="$TMP/bin:$PATH" CALLS="$CALLS" SWAYNC_HINT_PI_FOCUS_PID="999" SWAYNC_APP_NAME="Pi" "$SCRIPT"
grep -q 'address:0/chrome' "$CALLS" || {
  echo "FAIL: Pi focus hint did not focus exact window pid 999" >&2
  cat "$CALLS" >&2 || true
  exit 1
}

: >"$CALLS"
PATH="/usr/sbin:/usr/bin:/bin" SWAYNC_APP_NAME="Missing Hyprctl" "$SCRIPT"

cat >"$TMP/bin/hyprctl" <<'SH'
#!/usr/bin/env bash
exit 1
SH
chmod +x "$TMP/bin/hyprctl"
PATH="$TMP/bin:/usr/bin:/bin" CALLS="$CALLS" SWAYNC_APP_NAME="Broken Hyprctl" "$SCRIPT"

echo "hypr focus notification smoke test passed"
