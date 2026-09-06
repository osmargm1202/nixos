#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT/nixos/profiles/i3.nix"
CONFIG="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"
HELPER="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-caffeine-toggle"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

! grep -Fqi 'i3blocks' "$PROFILE" "$CONFIG" ||
  fail 'i3blocks integration remains after replacing the bar'

[ -x "$HELPER" ] || fail 'i3-caffeine-toggle missing or not executable'
grep -Fq 'bindsym $mod+Shift+c exec --no-startup-id $run i3-caffeine-toggle' "$CONFIG" || fail 'caffeine keyboard shortcut missing'
grep -Fq 'exec --no-startup-id $run i3-caffeine-toggle off' "$CONFIG" || fail 'i3 startup must leave caffeine disabled'
grep -Fq 'flock 9' "$HELPER" || fail 'caffeine transitions are not serialized'
grep -Fq 'mktemp "$state_file.tmp.XXXXXX"' "$HELPER" || fail 'caffeine state is not written atomically'
grep -Fq 'valid_state' "$HELPER" || fail 'corrupt caffeine state is not validated'
WRAPPER="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3status-localized"
STATUS_CONFIG="$ROOT/dotfiles/config/profiles/i3/.config/i3/i3status.conf"
[ -x "$WRAPPER" ] || fail 'i3status wrapper missing or not executable'
grep -Fq 'interval = 1' "$STATUS_CONFIG" || fail 'status bar does not refresh caffeine promptly'
! grep -Fq 'order += "load"' "$STATUS_CONFIG" || fail 'load average remains instead of CPU percentage'
grep -Fq '"click_events":true' "$WRAPPER" || fail 'i3bar click events are not enabled'
grep -Fq 'format_up = "%ip"' "$STATUS_CONFIG" || fail 'Wi-Fi must expose its IP address'
grep -Fq 'format = "%status %percentage"' "$STATUS_CONFIG" || fail 'battery source must expose status and percentage'
grep -Fq 'separator_symbol "│"' "$CONFIG" || fail 'status blocks must have a visible separator'
grep -Fq 'exec --no-startup-id $run i3-idle-inhibit' "$CONFIG" || fail 'idle inhibitor is not started by i3'

python3 - "$WRAPPER" <<'PY'
import importlib.machinery
import importlib.util
import sys
from types import SimpleNamespace

loader = importlib.machinery.SourceFileLoader("i3status_localized", sys.argv[1])
spec = importlib.util.spec_from_loader(loader.name, loader)
wrapper = importlib.util.module_from_spec(spec)
loader.exec_module(wrapper)
wrapper.system_battery = lambda: None
GIB_KIB = 1024 * 1024
blocks = {block["name"]: block for block in wrapper.resource_blocks(76, 100 * GIB_KIB, 49 * GIB_KIB, 20 * 1024**3, True)}
assert blocks["caffeine"]["full_text"] == wrapper.ICON_CAFFEINE_ON
assert blocks["cpu"] == {"name": "cpu", "full_text": f"{wrapper.ICON_CPU} 76%", "color": wrapper.CPU_WARNING}
assert blocks["memory"] == {"name": "memory", "full_text": f"{wrapper.ICON_MEMORY} 49.00 GiB", "color": wrapper.RAM_WARNING}
assert blocks["disk"]["full_text"] == f"{wrapper.ICON_DISK} 20 GiB"
assert wrapper.localize({"name": "battery 0", "full_text": "BAT 10%"})["full_text"] == f"{wrapper.BATTERY_ICONS[1]} 10%"
assert wrapper.localize({"name": "battery 0", "full_text": "CHR 87%"})["full_text"] == f"{wrapper.BATTERY_CHARGING} 87%"
assert wrapper.localize({"name": "wireless", "full_text": "72%"})["full_text"] == f"{wrapper.ICON_WIFI} 72%"
assert wrapper.localize({"name": "wireless", "full_text": "W: down"})["full_text"] == wrapper.ICON_WIFI_OFF
original_run = wrapper.subprocess.run
wrapper.subprocess.run = lambda *_args, **_kwargs: SimpleNamespace(stdout="us(altgr-intl)\n")
assert wrapper.keyboard_block()["full_text"] == f"{wrapper.ICON_KEYBOARD} US"
wrapper.subprocess.run = original_run
wrapper.system_battery = lambda: (42, True)
assert wrapper.battery_block({"name": "battery 0", "full_text": "BAT 1%"})["full_text"] == f"{wrapper.BATTERY_CHARGING} 42%"
clicks = []
wrapper.subprocess.Popen = lambda command, **_kwargs: clicks.append(command)
wrapper.click_action({"name": "caffeine", "button": 1})
wrapper.click_action({"name": "keyboard", "button": 1})
assert clicks[0][-1] == "toggle"
assert clicks[1] == ["xkb-switch", "-n"]

blocks = {block["name"]: block for block in wrapper.resource_blocks(90, 100 * GIB_KIB, 10 * GIB_KIB, 20 * 1024**3, False)}
assert blocks["cpu"]["color"] == wrapper.CPU_WARNING
blocks = {block["name"]: block for block in wrapper.resource_blocks(91, 100 * GIB_KIB, 10 * GIB_KIB, 20 * 1024**3, False)}
assert blocks["cpu"]["color"] == wrapper.CRITICAL
assert blocks["memory"]["color"] == wrapper.CRITICAL
assert blocks["memory"]["full_text"] == f"{wrapper.ICON_MEMORY} 10.00 GiB"
PY
bash -n "$HELPER"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/status-bin" "$tmp/power/BAT0"
printf '20\n' >"$tmp/power/BAT0/capacity"
printf 'Discharging\n' >"$tmp/power/BAT0/status"
cat >"$tmp/status-bin/i3status" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' '{"version":1}' '[' '[{"name":"wireless","full_text":"75%"},{"name":"ethernet","full_text":"down"},{"name":"battery 0","full_text":"BAT 20%"},{"name":"tztime","full_text":"Wednesday 29 - July - 2026"}]'
sleep 1
STUB
cat >"$tmp/status-bin/i3-caffeine-toggle" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$CAFFEINE_CLICK_CALLS"
STUB
cat >"$tmp/status-bin/xkb-switch" <<'STUB'
#!/usr/bin/env bash
case "${1:-}" in
  -p) printf '%s\n' LATAM ;;
  -n) printf '%s\n' "$*" >>"$KEYBOARD_CLICK_CALLS" ;;
  *) exit 64 ;;
esac
STUB
chmod +x "$tmp/status-bin/i3status" "$tmp/status-bin/i3-caffeine-toggle" "$tmp/status-bin/xkb-switch"
export CAFFEINE_CLICK_CALLS="$tmp/click-calls"
export KEYBOARD_CLICK_CALLS="$tmp/keyboard-click-calls"
mkdir -p "$tmp/home/.local/bin"
ln -s "$tmp/status-bin/i3-caffeine-toggle" "$tmp/home/.local/bin/i3-caffeine-toggle"
printf '[\n{"name":"caffeine","button":1}\n,{"name":"keyboard","button":1}\n' |
  HOME="$tmp/home" I3_POWER_SUPPLY_PATH="$tmp/power" PATH="$tmp/status-bin:$PATH" "$WRAPPER" >"$tmp/status-output"
grep -Fq '"click_events":true' "$tmp/status-output" || fail 'wrapper did not advertise click events'
grep -Fq '"full_text":" 75%"' "$tmp/status-output" || fail 'Wi-Fi icon missing from status output'
grep -Fq '"full_text":"󰈀"' "$tmp/status-output" || fail 'Ethernet icon missing from status output'
grep -Fq '"full_text":" 20%"' "$tmp/status-output" || fail 'dynamic battery icon missing from status output'
grep -Fq '"full_text":" LATAM"' "$tmp/status-output" || fail 'active keyboard layout missing from status output'
grep -Fq '' "$tmp/status-output" || fail 'CPU icon missing from status output'
grep -Fq '󰍛' "$tmp/status-output" || fail 'RAM icon missing from status output'
grep -Fq '󰋊' "$tmp/status-output" || fail 'SSD icon missing from status output'
grep -Fxq 'toggle' "$tmp/click-calls" || fail 'caffeine bar click did not toggle mode'
grep -Fxq -- '-n' "$tmp/keyboard-click-calls" || fail 'keyboard bar click did not switch layout'
mkdir -p "$tmp/bin"
cat >"$tmp/bin/xset" <<'STUB'
#!/usr/bin/env bash
if [[ "${1:-}" == q ]]; then
  cat <<'OUT'
Screen Saver:
  timeout:  600    cycle:  600
DPMS (Energy Star):
  Standby: 600    Suspend: 600    Off: 600
  DPMS is Enabled
OUT
  exit 0
fi
printf 'xset %s\n' "$*" >>"$CAFFEINE_CALLS"
if [[ "${XSET_FAIL_RESTORE:-0}" == 1 && "$*" == 's 600 600' ]]; then exit 7; fi
STUB
cat >"$tmp/bin/notify-send" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
chmod +x "$tmp/bin/xset" "$tmp/bin/notify-send"
export CAFFEINE_CALLS="$tmp/calls"
XDG_STATE_HOME="$tmp/state" PATH="$tmp/bin:$PATH" "$HELPER" on
[[ -f "$tmp/state/i3/caffeine" ]] || fail 'caffeine state not persisted'
grep -Fxq 'xset s off' "$tmp/calls" || fail 'caffeine did not disable screen saver'
grep -Fxq 'xset -dpms' "$tmp/calls" || fail 'caffeine did not disable DPMS'
: >"$tmp/calls"
XDG_STATE_HOME="$tmp/state" PATH="$tmp/bin:$PATH" "$HELPER" on
grep -Fxq 'xset s off' "$tmp/calls" || fail 'existing caffeine state is not re-applied'
grep -Fxq 'xset -dpms' "$tmp/calls" || fail 'existing caffeine state leaves DPMS enabled'
XDG_STATE_HOME="$tmp/state" PATH="$tmp/bin:$PATH" "$HELPER" off
[[ ! -f "$tmp/state/i3/caffeine" ]] || fail 'caffeine state not cleared'
grep -Fxq 'xset s 600 600' "$tmp/calls" || fail 'screen saver settings not restored'
grep -Fxq 'xset dpms 600 600 600' "$tmp/calls" || fail 'DPMS settings not restored'
mkdir -p "$tmp/state/i3"
printf 'corrupt\n' >"$tmp/state/i3/caffeine"
XDG_STATE_HOME="$tmp/state" PATH="$tmp/bin:$PATH" "$HELPER" off
[[ ! -f "$tmp/state/i3/caffeine" ]] || fail 'corrupt caffeine state survived recovery'
XDG_STATE_HOME="$tmp/state" PATH="$tmp/bin:$PATH" "$HELPER" on
if XSET_FAIL_RESTORE=1 XDG_STATE_HOME="$tmp/state" PATH="$tmp/bin:$PATH" "$HELPER" off; then
  fail 'partial xset restoration was reported as success'
fi
[[ -f "$tmp/state/i3/caffeine" ]] || fail 'failed restoration discarded recovery state'
XDG_STATE_HOME="$tmp/state" PATH="$tmp/bin:$PATH" "$HELPER" off

printf 'PASS: larger Noto Nord bar has one volume applet and caffeine control\n'
