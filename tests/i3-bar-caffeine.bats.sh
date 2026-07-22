#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMON="$ROOT/nixos/common.nix"
PROFILE="$ROOT/nixos/profiles/i3.nix"
CONFIG="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"
ICONS="$ROOT/dotfiles/config/profiles/i3/.config/bumblebee-status/themes/icons/i3-clean.json"
HELPER="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-caffeine-toggle"
DOTFILES="$ROOT/nixos/common-dotfiles.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

grep -Eq '^[[:space:]]+noto-fonts[[:space:]]*$' "$COMMON" || fail 'Noto Sans font package missing'
grep -Eq '^[[:space:]]+font-awesome[[:space:]]*$' "$COMMON" || fail 'Font Awesome package missing'
grep -Fq 'font pango:Noto Sans, JetBrainsMono Nerd Font 18' "$CONFIG" ||
  fail 'bar font lacks full-height Nerd Font Powerline fallback'
grep -Fq 'height 28' "$CONFIG" || fail 'Powerline-proportioned i3bar height missing'

[[ "$(grep -Fc 'pasystray' "$CONFIG")" -eq 0 ]] || fail 'explicit pasystray duplicates its XDG autostart'
grep -Eq '^[[:space:]]+pasystray[[:space:]]*$' "$PROFILE" || fail 'pasystray package/autostart source missing'

grep -Fq 'bumblebeeI3 = ' "$PROFILE" ||
  fail 'Bumblebee clean iconset and shortcut/date/time plugins missing'
grep -Fq 'status_command bumblebee-status -m shortcut date time' "$CONFIG" || fail 'caffeine bar button missing'
grep -Fq 'shortcut.cmds="$HOME/.local/bin/i3-caffeine-toggle"' "$CONFIG" || fail 'portable caffeine button command missing'
grep -Fq -- '-i i3-clean -t nord-powerline' "$CONFIG" || fail 'clean icons or Nord theme missing'
[ -f "$ICONS" ] || fail 'calendar-safe Bumblebee iconset missing'
jq -e '.date.prefix == "" and .time.prefix == ""' "$ICONS" >/dev/null || fail 'date/time icons still overlap text'

[ -x "$HELPER" ] || fail 'i3-caffeine-toggle missing or not executable'
grep -Fq 'bindsym $mod+Shift+c exec --no-startup-id $run i3-caffeine-toggle' "$CONFIG" || fail 'caffeine keyboard shortcut missing'
grep -Fq 'exec --no-startup-id $run i3-caffeine-toggle off' "$CONFIG" || fail 'stale caffeine state is not reset at login'
grep -Fq '".local/bin/i3-caffeine-toggle"' "$DOTFILES" || fail 'caffeine helper not deployed'
grep -Fq '".config/bumblebee-status"' "$DOTFILES" || fail 'Bumblebee iconset not deployed'
grep -Fq 'flock 9' "$HELPER" || fail 'caffeine transitions are not serialized'
grep -Fq 'mktemp "$state_file.tmp.XXXXXX"' "$HELPER" || fail 'caffeine state is not written atomically'
grep -Fq 'valid_state' "$HELPER" || fail 'corrupt caffeine state is not validated'
bash -n "$HELPER"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
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
