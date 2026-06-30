#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/config/shared/.local/bin/hypr-random-wallpaper"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

mkdir -p "$TMP/home/Pictures/Wallpapers" "$TMP/runtime" "$TMP/state" "$TMP/bin"
touch "$TMP/home/Pictures/Wallpapers/a.png"
cat > "$TMP/bin/hyprctl" <<'STUB'
#!/usr/bin/env bash
echo "hyprctl $*" >> "$CALLS"
STUB
chmod +x "$TMP/bin/hyprctl"

CALLS="$TMP/calls.log"
export CALLS

grep -q '^is_own_daemon_pid()' "$SCRIPT" || fail "missing daemon pid ownership helper"
awk '/^is_own_daemon_pid\(\) /,/^}/' "$SCRIPT" | grep -q 'ps -p "\$pid" -o args=' || fail "daemon pid ownership helper does not inspect process args"
awk '/^run_daemon\(\) /,/^}/' "$SCRIPT" | grep -q 'is_own_daemon_pid "$old_pid"' || fail "daemon startup kill is not guarded by ownership check"
awk '/^stop_daemon\(\) /,/^}/' "$SCRIPT" | grep -q 'is_own_daemon_pid "$pid"' || fail "daemon stop kill is not guarded by ownership check"

PATH="$TMP/bin:$PATH" HOME="$TMP/home" XDG_RUNTIME_DIR="$TMP/runtime" XDG_STATE_HOME="$TMP/state" SWAY_WALLPAPER_INTERVAL=1800 "$SCRIPT" next

grep -q 'hyprctl hyprpaper' "$CALLS" || grep -q 'hyprctl dispatch' "$CALLS" || grep -q 'hyprctl keyword' "$CALLS" || fail "wallpaper script did not call hyprctl in next mode"
[ -s "$TMP/state/hypr-random-wallpaper.current" ] || [ -s "$TMP/runtime/hypr-random-wallpaper.current" ] || fail "current wallpaper state was not written"

echo "hypr random wallpaper smoke test passed"
