#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/config/shared/.local/bin/hypr-battery-alerts"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

mkdir -p "$TMP/bin" "$TMP/state"
cat > "$TMP/bin/notify-send" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$CALLS"
STUB
chmod +x "$TMP/bin/notify-send"

CALLS="$TMP/calls" PATH="$TMP/bin:$PATH" XDG_STATE_HOME="$TMP/state" HYPR_BATTERY_ALERT_CAPACITY=50 HYPR_BATTERY_ALERT_STATUS=Discharging "$SCRIPT" once
rg -q 'Batería al 50%.*󰁾 50%' "$TMP/calls" || fail "missing 50% alert"

CALLS="$TMP/calls" PATH="$TMP/bin:$PATH" XDG_STATE_HOME="$TMP/state" HYPR_BATTERY_ALERT_CAPACITY=50 HYPR_BATTERY_ALERT_STATUS=Discharging "$SCRIPT" once
[ "$(wc -l < "$TMP/calls")" -eq 1 ] || fail "50% alert repeated"

CALLS="$TMP/calls" PATH="$TMP/bin:$PATH" XDG_STATE_HOME="$TMP/state" HYPR_BATTERY_ALERT_CAPACITY=10 HYPR_BATTERY_ALERT_STATUS=Discharging "$SCRIPT" once
rg -q -- '-u critical.*✖ BATERÍA CRÍTICA.*🔴 󰂃 10%' "$TMP/calls" || fail "missing critical 10% alert"

CALLS="$TMP/calls" PATH="$TMP/bin:$PATH" XDG_STATE_HOME="$TMP/state" HYPR_BATTERY_ALERT_CAPACITY=20 HYPR_BATTERY_ALERT_STATUS=Charging "$SCRIPT" once
CALLS="$TMP/calls" PATH="$TMP/bin:$PATH" XDG_STATE_HOME="$TMP/state" HYPR_BATTERY_ALERT_CAPACITY=20 HYPR_BATTERY_ALERT_STATUS=Discharging "$SCRIPT" once
rg -q 'Batería baja.*󰁻 20%' "$TMP/calls" || fail "charging did not reset threshold state"

echo "hypr battery alerts smoke test passed"
