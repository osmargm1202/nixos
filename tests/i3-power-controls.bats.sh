#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"
POWER="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-powermenu"
XLOGOUT="$ROOT/dotfiles/config/profiles/i3/.config/xlogout/xlogout.conf"
INHIBITOR="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-idle-inhibit"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

grep -Fq 'bindsym $mod+Mod1+p exec --no-startup-id $run i3-powermenu' "$CONFIG" ||
  fail 'Win+Alt+P does not open the power menu'
! grep -Fq 'bindsym $mod+Mod1+p exec --no-startup-id xset dpms force off' "$CONFIG" ||
  fail 'Win+Alt+P still only disables the display'
grep -Fq 'exec --no-startup-id $run i3-caffeine-toggle off' "$CONFIG" ||
  fail 'i3 does not clear the persistent caffeine inhibitor at startup'
! grep -Fq 'i3-caffeine-toggle on' "$CONFIG" ||
  fail 'i3 starts with the sleep inhibitor enabled'
grep -Fq 'bindsym $mod+Shift+o exec --no-startup-id systemctl suspend' "$CONFIG" ||
  fail 'direct suspend binding missing'
grep -Fq 'Suspend) exec systemctl suspend ;;' "$POWER" ||
  fail 'power menu suspend missing'
grep -Fq 'command = systemctl suspend' "$XLOGOUT" ||
  fail 'xlogout suspend missing'
grep -Fq -- '--what=idle' "$INHIBITOR" ||
  fail 'idle inhibitor does not limit itself to idle sleep prevention'
! grep -Fq -- '--what=idle:sleep' "$INHIBITOR" ||
  fail 'idle inhibitor blocks explicit suspend'
bash -n "$POWER" "$INHIBITOR"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
mkdir -p "$tmp_dir/bin"
cat >"$tmp_dir/bin/i3-rofi" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' Suspend
EOF
cat >"$tmp_dir/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$SYSTEMCTL_CALLS"
EOF
chmod +x "$tmp_dir/bin/i3-rofi" "$tmp_dir/bin/systemctl"
export SYSTEMCTL_CALLS="$tmp_dir/systemctl.calls"
PATH="$tmp_dir/bin:$PATH" "$POWER"
grep -Fxq 'suspend' "$SYSTEMCTL_CALLS" ||
  fail 'Suspend menu action did not invoke systemctl suspend'

printf '%s\n' 'PASS: i3 power controls open the menu and preserve explicit suspend'
