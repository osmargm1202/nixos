#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/config/shared/.local/bin/hypr-audio-device-menu"
FIXTURE_DIR="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

WPCTL_LOG="$FIXTURE_DIR/wpctl.log"
DMENU_LOG="$FIXTURE_DIR/dmenu.log"

cat >"$FIXTURE_DIR/wpctl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  status)
    cat <<'EOF'
Audio
 ├─ Devices:
 │      45. Built-in Audio Controller
 ├─ Sinks:
 │  *   51. Built-in Audio Analog Stereo [vol: 0.40]
 │      52. Corsair HS55 SURROUND Analog Stereo [vol: 0.70]
 ├─ Sources:
 │  *   60. Built-in Audio Analog Stereo [vol: 0.50]
 │      61. Webcam Microphone [vol: 0.80]
 └─ Streams:
EOF
    ;;
  set-default)
    echo "set-default $2" >>"$WPCTL_LOG"
    ;;
  *)
    echo "unexpected wpctl args: $*" >&2
    exit 1
    ;;
esac
SH
chmod +x "$FIXTURE_DIR/wpctl"

cat >"$FIXTURE_DIR/dmenu" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
cat >"$DMENU_LOG"
case "${HYPR_AUDIO_TEST_SELECTION:-}" in
  output) printf '52\tCorsair HS55 SURROUND Analog Stereo\n' ;;
  input) printf '61\tWebcam Microphone\n' ;;
  empty) exit 0 ;;
  *) echo "unknown selection" >&2; exit 2 ;;
esac
SH
chmod +x "$FIXTURE_DIR/dmenu"

export WPCTL_LOG DMENU_LOG
export HYPR_AUDIO_WPCTL="$FIXTURE_DIR/wpctl"
export HYPR_AUDIO_DMENU_CMD="$FIXTURE_DIR/dmenu"

HYPR_AUDIO_TEST_SELECTION=output "$SCRIPT" output
grep -qx 'set-default 52' "$WPCTL_LOG"
grep -q $'51\tBuilt-in Audio Analog Stereo' "$DMENU_LOG"
grep -q $'52\tCorsair HS55 SURROUND Analog Stereo' "$DMENU_LOG"

: >"$WPCTL_LOG"
: >"$DMENU_LOG"
HYPR_AUDIO_TEST_SELECTION=input "$SCRIPT" input
grep -qx 'set-default 61' "$WPCTL_LOG"
grep -q $'60\tBuilt-in Audio Analog Stereo' "$DMENU_LOG"
grep -q $'61\tWebcam Microphone' "$DMENU_LOG"

: >"$WPCTL_LOG"
HYPR_AUDIO_TEST_SELECTION=empty "$SCRIPT" output
if [ -s "$WPCTL_LOG" ]; then
  echo "expected empty selection to leave default unchanged" >&2
  cat "$WPCTL_LOG" >&2
  exit 1
fi
