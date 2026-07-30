#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT/nixos/profiles/i3.nix"
CONFIG="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"
HELPER="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-caffeine-toggle"
DOTFILES="$ROOT/nixos/common-dotfiles.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

! grep -Fqi 'i3blocks' "$PROFILE" "$CONFIG" "$DOTFILES" ||
  fail 'i3blocks integration remains after replacing the bar'

[ -x "$HELPER" ] || fail 'i3-caffeine-toggle missing or not executable'
grep -Fq 'bindsym $mod+Shift+c exec --no-startup-id $run i3-caffeine-toggle' "$CONFIG" || fail 'caffeine keyboard shortcut missing'
grep -Fq 'exec --no-startup-id $run i3-caffeine-toggle on' "$CONFIG" || fail 'i3 login does not keep displays awake'
grep -Fq '".local/bin/i3-caffeine-toggle"' "$DOTFILES" || fail 'caffeine helper not deployed'
! grep -Fq '".config/i3blocks"' "$DOTFILES" || fail 'i3blocks config is still deployed'
grep -Fq 'flock 9' "$HELPER" || fail 'caffeine transitions are not serialized'
grep -Fq 'mktemp "$state_file.tmp.XXXXXX"' "$HELPER" || fail 'caffeine state is not written atomically'
grep -Fq 'valid_state' "$HELPER" || fail 'corrupt caffeine state is not validated'
WRAPPER="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3status-localized"
STATUS_CONFIG="$ROOT/dotfiles/config/profiles/i3/.config/i3/i3status.conf"
[ -x "$WRAPPER" ] || fail 'i3status wrapper missing or not executable'
grep -Fq 'interval = 1' "$STATUS_CONFIG" || fail 'status bar does not refresh caffeine promptly'
! grep -Fq 'order += "load"' "$STATUS_CONFIG" || fail 'load average remains instead of CPU percentage'
grep -Fq '"click_events":true' "$WRAPPER" || fail 'i3bar click events are not enabled'

python3 - "$WRAPPER" <<'PY'
import importlib.machinery
import importlib.util
import sys

loader = importlib.machinery.SourceFileLoader("i3status_localized", sys.argv[1])
spec = importlib.util.spec_from_loader(loader.name, loader)
wrapper = importlib.util.module_from_spec(spec)
loader.exec_module(wrapper)
GIB_KIB = 1024 * 1024
blocks = {block["name"]: block for block in wrapper.resource_blocks(76, 100 * GIB_KIB, 49 * GIB_KIB, 20 * 1024**3, True)}
assert blocks["caffeine"]["full_text"] == "Café: ON"
assert blocks["cpu"] == {"name": "cpu", "full_text": "CPU: 76%", "color": wrapper.CPU_WARNING}
assert blocks["memory"] == {"name": "memory", "full_text": "RAM: 49.00 GiB", "color": wrapper.RAM_WARNING}
assert blocks["disk"]["full_text"] == "SDD: 20 GiB"

blocks = {block["name"]: block for block in wrapper.resource_blocks(90, 100 * GIB_KIB, 10 * GIB_KIB, 20 * 1024**3, False)}
assert blocks["cpu"]["color"] == wrapper.CPU_WARNING
blocks = {block["name"]: block for block in wrapper.resource_blocks(91, 100 * GIB_KIB, 10 * GIB_KIB, 20 * 1024**3, False)}
assert blocks["cpu"]["color"] == wrapper.CRITICAL
assert blocks["memory"]["color"] == wrapper.CRITICAL
assert blocks["memory"]["full_text"] == "RAM: 10.00 GiB"
PY
bash -n "$HELPER"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/status-bin"
cat >"$tmp/status-bin/i3status" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' '{"version":1}' '[' '[{"name":"tztime","full_text":"Wednesday 29 - July - 2026"}]'
sleep 1
STUB
cat >"$tmp/status-bin/i3-caffeine-toggle" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$CAFFEINE_CLICK_CALLS"
STUB
chmod +x "$tmp/status-bin/i3status" "$tmp/status-bin/i3-caffeine-toggle"
export CAFFEINE_CLICK_CALLS="$tmp/click-calls"
mkdir -p "$tmp/home/.local/bin"
ln -s "$tmp/status-bin/i3-caffeine-toggle" "$tmp/home/.local/bin/i3-caffeine-toggle"
printf '[\n{"name":"caffeine","button":1}\n' |
  HOME="$tmp/home" PATH="$tmp/status-bin:$PATH" "$WRAPPER" >"$tmp/status-output"
grep -Fq '"click_events":true' "$tmp/status-output" || fail 'wrapper did not advertise click events'
grep -Fxq 'toggle' "$tmp/click-calls" || fail 'caffeine bar click did not toggle mode'
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
