#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/config/profiles/hyprland/.local/bin/hypr-bluetooth-reconnect"
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

for ((attempt = 0; attempt < 50; attempt++)); do
  [[ -f $CALLS ]] && break
  sleep 0.02
done
[[ -f $CALLS ]] || {
  echo "FAIL: kitty did not receive the USB reset command" >&2
  exit 1
}

grep -q 'kitty .*bash -lc.*printf usb-reset' "$CALLS" || {
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
