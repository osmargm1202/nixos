#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER="$ROOT/dotfiles/config/shared/.local/bin/external-lid-inhibit"
fail(){ printf 'FAIL: %s\n' "$*" >&2; exit 1; }
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT; mkdir -p "$tmp/bin"
cat >"$tmp/bin/systemd-inhibit" <<'EOF'
#!/usr/bin/env bash
printf 'start\n' >>"$LOG"; trap 'printf "stop\n" >>"$LOG"; exit' TERM INT; sleep infinity
EOF
cat >"$tmp/bin/xrandr" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$XRANDR_OUTPUT"
EOF
cat >"$tmp/bin/hyprctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$MONITOR_JSON"
EOF
cat >"$tmp/bin/wlr-randr" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$MONITOR_JSON"
EOF
chmod +x "$tmp/bin/"*
run_case(){ local output="$1" expected="$2"; : >"$tmp/log"; XRANDR_OUTPUT="$output" LOG="$tmp/log" XDG_CURRENT_DESKTOP=i3 EXTERNAL_LID_INHIBIT_INTERVAL=.05 PATH="$tmp/bin:$PATH" "$HELPER" & local pid=$!; sleep .15; kill "$pid"; wait "$pid" 2>/dev/null || true; [[ "$(<"$tmp/log")" == "$expected" ]] || fail "unexpected inhibitor state: $(<"$tmp/log")"; }
run_case $'Monitors: 1\n 0: +*HDMI-1' $'start\nstop'
run_case $'Monitors: 2\n 0: +*eDP-1\n 1: +HDMI-1' ''
run_case $'Monitors: 2\n 0: +*HDMI-1\n 1: +DP-1' ''
run_json_case(){ local desktop="$1" output="$2" expected="$3"; : >"$tmp/log"; MONITOR_JSON="$output" LOG="$tmp/log" XDG_CURRENT_DESKTOP="$desktop" EXTERNAL_LID_INHIBIT_INTERVAL=.05 PATH="$tmp/bin:$PATH" "$HELPER" & local pid=$!; sleep .15; kill "$pid"; wait "$pid" 2>/dev/null || true; [[ "$(<"$tmp/log")" == "$expected" ]] || fail "$desktop: unexpected inhibitor state: $(<"$tmp/log")"; }
for desktop in Hyprland labwc; do
  run_json_case "$desktop" '[{"name":"HDMI-A-1","enabled":true}]' $'start\nstop'
  run_json_case "$desktop" '[{"name":"eDP-1","enabled":true}]' ''
  run_json_case "$desktop" '[{"name":"HDMI-A-1","enabled":true},{"name":"DP-1","enabled":true}]' ''
done
printf 'PASS: external-only lid inhibition is exact in i3, Hyprland and Labwc\n'
