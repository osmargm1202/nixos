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
chmod +x "$tmp/bin/systemd-inhibit"

run_case() {
  local internal="$1" external="$2" expected="$3"
  local drm="$tmp/drm"

  rm -rf "$drm"
  mkdir -p "$drm/card0-eDP-1" "$drm/card0-HDMI-A-1"
  printf '%s\n' "$internal" >"$drm/card0-eDP-1/status"
  printf '%s\n' "$external" >"$drm/card0-HDMI-A-1/status"
  : >"$tmp/log"

  LOG="$tmp/log" EXTERNAL_LID_INHIBIT_DRM_ROOT="$drm" \
    EXTERNAL_LID_INHIBIT_INTERVAL=.05 PATH="$tmp/bin:$PATH" "$HELPER" &
  local pid=$!
  sleep .15
  kill "$pid"
  wait "$pid" 2>/dev/null || true
  [[ "$(<"$tmp/log")" == "$expected" ]] || fail "unexpected inhibitor state: $(<"$tmp/log")"
}

run_case connected connected $'start\nstop'
run_case connected disconnected ''
run_case disconnected connected $'start\nstop'
run_case disconnected disconnected ''
printf 'PASS: external display lid inhibition uses DRM connector state\n'
