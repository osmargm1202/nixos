#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT/nixos/profiles/i3.nix"
CONFIG="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"
AUTOSTART="$ROOT/dotfiles/config/profiles/i3/.config/autostart/autorandr.desktop"
HELPER="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-monitor-profile"
DEVICES="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-devices-menu"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

grep -Fq 'services.autorandr = {' "$PROFILE" || fail 'autorandr hotplug service missing'
grep -Fq 'enable = true;' "$PROFILE" || fail 'autorandr service not enabled'
grep -Fq 'defaultTarget = "horizontal";' "$PROFILE" || fail 'autorandr fallback must activate connected screens horizontally'
grep -Fq 'matchEdid = true;' "$PROFILE" || fail 'autorandr must match physical monitor EDIDs'

[ -f "$AUTOSTART" ] || fail 'i3 Autorandr autostart override missing'
grep -Fq 'Hidden=true' "$AUTOSTART" || fail 'packaged Autorandr XDG startup must be disabled'
if grep -Fq 'Exec=' "$AUTOSTART"; then fail 'disabled Autorandr desktop still executes'; fi
grep -Fq 'exec --no-startup-id $run i3-monitor-profile --apply --quiet' "$CONFIG" ||
  fail 'i3 login profile restore must not notify'
grep -Fq 'exec --no-startup-id $run i3-caffeine-toggle off' "$CONFIG" ||
  fail 'i3 startup must leave caffeine disabled until explicitly enabled'
! grep -Fq 'i3-caffeine-toggle on' "$CONFIG" ||
  fail 'i3 startup must not enable caffeine automatically'
grep -Fq "exec --no-startup-id sh -lc 'command -v discord >/dev/null 2>&1 && exec discord --start-minimized || true'" "$CONFIG" ||
  fail 'Discord login launch must start minimized when available'
grep -Fq 'bindsym $mod+p exec --no-startup-id $run i3-monitor-profile' "$CONFIG" || fail 'display menu shortcut missing'
grep -Fq 'Displays) exec i3-monitor-profile' "$DEVICES" || fail 'Devices menu does not open monitor profiles'

[ -x "$HELPER" ] || fail 'i3-monitor-profile missing or not executable'
grep -Fq 'autorandr --change --force --default horizontal --match-edid' "$HELPER" || fail 'EDID-aware detected profile restore command missing'
grep -Fq 'autorandr --save "$profile" --force' "$HELPER" || fail 'runtime profile save command missing'
grep -Fq 'Configure) exec arandr' "$HELPER" || fail 'ARandR GUI action missing'

bash -n "$HELPER"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
cat >"$tmp/bin/autorandr" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$AUTORANDR_CALLS"
if [[ -n "${AUTORANDR_FAIL:-}" && "${1:-}" == "$AUTORANDR_FAIL" ]]; then
  printf 'simulated autorandr failure\n' >&2
  exit 7
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
chmod +x "$tmp/bin/autorandr" "$tmp/bin/i3-wallpaper" "$tmp/bin/notify-send"
export AUTORANDR_CALLS="$tmp/calls" NOTIFY_CALLS="$tmp/notifications"
PATH="$tmp/bin:$PATH" "$HELPER" --save docked
PATH="$tmp/bin:$PATH" "$HELPER" --apply
PATH="$tmp/bin:$PATH" "$HELPER" --load docked
notification_count="$(wc -l <"$tmp/notifications")"
PATH="$tmp/bin:$PATH" "$HELPER" --apply --quiet
[[ "$(wc -l <"$tmp/notifications")" -eq "$notification_count" ]] ||
  fail 'quiet apply emitted a startup notification'
grep -Fxq -- '--save docked --force' "$tmp/calls" || fail 'save did not persist named profile'
grep -Fxq -- '--change --force --default horizontal --match-edid' "$tmp/calls" || fail 'apply did not detect by EDID and restore profile'
grep -Fxq -- '--load docked --force' "$tmp/calls" || fail 'load did not restore named profile'

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

printf 'PASS: autorandr detects hotplug and restores runtime-owned i3 monitor profiles\n'
