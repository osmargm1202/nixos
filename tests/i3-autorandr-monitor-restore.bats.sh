#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-monitor-profile"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[ -x "$HELPER" ] || fail 'i3-monitor-profile missing or not executable'

bash -n "$HELPER"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
cat >"$tmp/bin/autorandr" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$AUTORANDR_CALLS"
if [[ "${1:-}" == --detected ]]; then
  [[ -n "${AUTORANDR_DETECTED-docked}" ]] && printf '%s\n' "${AUTORANDR_DETECTED-docked}"
  exit 0
fi
if [[ -n "${AUTORANDR_FAIL:-}" && "${1:-}" == "$AUTORANDR_FAIL" ]]; then
  printf 'simulated autorandr failure\n' >&2
  exit 7
fi
STUB
cat >"$tmp/bin/xrandr" <<'STUB'
#!/usr/bin/env bash
if [[ "${1:-}" == --query ]]; then
  printf '%s\n' "${XRANDR_QUERY:-}"
else
  printf '%s\n' "$*" >>"$XRANDR_CALLS"
fi
STUB
cat >"$tmp/bin/i3-wallpaper" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
cat >"$tmp/bin/notify-send" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$NOTIFY_CALLS"
STUB
chmod +x "$tmp/bin/autorandr" "$tmp/bin/xrandr" "$tmp/bin/i3-wallpaper" "$tmp/bin/notify-send"
export AUTORANDR_CALLS="$tmp/calls" XRANDR_CALLS="$tmp/xrandr-calls" NOTIFY_CALLS="$tmp/notifications"
PATH="$tmp/bin:$PATH" "$HELPER" --save docked
PATH="$tmp/bin:$PATH" "$HELPER" --apply
PATH="$tmp/bin:$PATH" "$HELPER" --load docked
notification_count="$(wc -l <"$tmp/notifications")"
PATH="$tmp/bin:$PATH" "$HELPER" --apply --quiet
[[ "$(wc -l <"$tmp/notifications")" -eq "$notification_count" ]] ||
  fail 'quiet apply emitted a startup notification'
grep -Fxq -- '--save docked --force' "$tmp/calls" || fail 'save did not persist named profile'
grep -Fxq -- '--change --force --match-edid' "$tmp/calls" || fail 'apply did not restore the EDID-matched profile'
grep -Fxq -- '--load docked --force' "$tmp/calls" || fail 'load did not restore named profile'
[[ ! -e "$XRANDR_CALLS" ]] || fail 'successful Autorandr profile unexpectedly ran the generic fallback'

XRANDR_QUERY=$'Screen 0: current 1920 x 1080\neDP-1 connected primary 1920x1080+0+0\nDP-2 connected'
AUTORANDR_DETECTED='' XRANDR_QUERY="$XRANDR_QUERY" PATH="$tmp/bin:$PATH" "$HELPER" --apply --quiet
grep -Fxq -- '--output DP-2 --auto --primary --pos 0x0 --output eDP-1 --auto --right-of DP-2' "$XRANDR_CALLS" ||
  fail 'unknown external display was not activated at its preferred mode as primary'

: >"$XRANDR_CALLS"
AUTORANDR_DETECTED=home AUTORANDR_FAIL=--change XRANDR_QUERY="$XRANDR_QUERY" PATH="$tmp/bin:$PATH" "$HELPER" --apply --quiet
grep -Fxq -- '--output DP-2 --auto --primary --pos 0x0 --output eDP-1 --auto --right-of DP-2' "$XRANDR_CALLS" ||
  fail 'failed detected profile did not fall back to the external primary layout'

before="$(wc -l <"$tmp/calls")"
if PATH="$tmp/bin:$PATH" "$HELPER" --save 'bad name'; then
  fail 'invalid profile name was accepted'
fi
[[ "$(wc -l <"$tmp/calls")" -eq "$before" ]] || fail 'invalid profile reached autorandr'
if AUTORANDR_FAIL=--save PATH="$tmp/bin:$PATH" "$HELPER" --save broken; then
  fail 'Autorandr save failure was hidden'
fi
grep -Fq 'Could not save broken: simulated autorandr failure' "$tmp/notifications" ||
  fail 'save failure did not notify user'

nix eval --json "path:$ROOT#nixosConfigurations.jarq-i3.config.home-manager.users.jarq.systemd.user.services.i3-monitor-hotplug.Service" >"$tmp/service.json"
python3 - "$tmp" "$HELPER" <<'PY'
import json
import pathlib
import shlex
import subprocess
import sys

root = pathlib.Path(sys.argv[1])
home = root / "home"
(home / ".local/bin").mkdir(parents=True)
(home / ".local/bin/i3-monitor-profile").symlink_to(sys.argv[2])
unit = json.loads((root / "service.json").read_text())
service_path = next(value[5:] for value in unit["Environment"] if value.startswith("PATH="))
service_path = service_path.replace("%h", str(home))
command = shlex.split(unit["ExecStart"][0].replace("%h", str(home)))
calls = root / "service-xrandr-calls"
subprocess.run(command, check=True, env={
    "HOME": str(home),
    "PATH": f"{root / 'bin'}:{service_path}",
    "AUTORANDR_DETECTED": "",
    "AUTORANDR_CALLS": str(root / "service-autorandr-calls"),
    "XRANDR_CALLS": str(calls),
    "NOTIFY_CALLS": str(root / "service-notifications"),
    "XRANDR_QUERY": "eDP-1 connected primary 1920x1080+0+0\nDP-2 connected",
})
assert calls.read_text().splitlines() == [
    "--output DP-2 --auto --primary --pos 0x0 --output eDP-1 --auto --right-of DP-2"
], "hotplug must restore an external-primary layout without an interactive-shell PATH"
PY

printf 'PASS: saved profiles take precedence and unknown external displays become primary\n'
