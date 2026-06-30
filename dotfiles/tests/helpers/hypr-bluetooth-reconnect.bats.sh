#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/config/shared/.local/bin/hypr-bluetooth-reconnect"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

CALLS="$TMP/calls.log"
mkdir -p "$TMP/bin"

cat >"$TMP/bin/kitty" <<'SH'
#!/usr/bin/env bash
echo "kitty $*" >>"$CALLS"
SH
chmod +x "$TMP/bin/kitty"

cat >"$TMP/bin/notify-send" <<'SH'
#!/usr/bin/env bash
echo "notify-send $*" >>"$CALLS"
SH
chmod +x "$TMP/bin/notify-send"

export CALLS
PATH="$TMP/bin:$PATH" HYPR_HEADSET_RECONNECT_CMD='printf usb-reset' "$SCRIPT"

grep -q 'kitty .*fish -lc.*printf usb-reset' "$CALLS" || {
  echo "FAIL: expected visible terminal USB reset command" >&2
  cat "$CALLS" >&2
  exit 1
}

if grep -q 'bluetoothctl' "$CALLS"; then
  echo "FAIL: bluetoothctl should not be used for USB headset reset" >&2
  cat "$CALLS" >&2
  exit 1
fi

echo "hypr bluetooth reconnect USB reset smoke test passed"
