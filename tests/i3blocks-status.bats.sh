#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT/nixos/profiles/i3.nix"
I3="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"
BLOCKS="$ROOT/dotfiles/config/profiles/i3/.config/i3blocks/config"
HELPER="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3blocks-status"
DOTFILES="$ROOT/nixos/common-dotfiles.nix"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[[ -f "$BLOCKS" ]] || fail 'i3blocks config missing'
[[ -x "$HELPER" ]] || fail 'portable i3blocks helper missing'
bash -n "$HELPER"
grep -Fq 'extraPackages = [ pkgs.i3blocks ];' "$PROFILE" || fail 'i3blocks package is not attached to i3'
grep -Fq 'status_command /run/current-system/sw/bin/i3blocks -c "$HOME/.config/i3blocks/config"' "$I3" ||
  fail 'i3bar does not launch the deployed i3blocks config'
! grep -Eqi 'bumblebee|i3-clean|i3-nord-powerline' "$PROFILE" "$I3" "$DOTFILES" ||
  fail 'Bumblebee status integration still exists'
grep -Fq '".config/i3blocks"' "$DOTFILES" || fail 'i3blocks config is not deployed'
grep -Fq '".local/bin/i3blocks-status"' "$DOTFILES" || fail 'i3blocks helper is not deployed'

for block in caffeine language brightness volume microphone disk network memory cpu temperature battery time; do
  grep -Fq "[$block]" "$BLOCKS" || fail "$block block missing"
done
grep -Eq '^[[:space:]]+brightnessctl[[:space:]]*$' "$PROFILE" || fail 'brightnessctl package missing'
for forbidden in apt-upgrades aptitude ufw wlp4s0 Tctl xbacklight /usr/share/i3blocks; do
  ! grep -Fq "$forbidden" "$BLOCKS" "$HELPER" || fail "non-portable upstream assumption remains: $forbidden"
done
grep -Fq 'separator=false' "$BLOCKS" || fail 'krasiyan separatorless block style missing'
grep -Fq 'background=#3B4252B3' "$BLOCKS" || fail 'translucent Nord block background missing'
grep -Fq 'command=$HOME/.local/bin/i3blocks-status "$BLOCK_NAME"' "$BLOCKS" ||
  fail 'blocks do not use PATH-independent dispatcher'
grep -Fq 'Adapted from krasiyan/dotfiles@009b6ce04029ba4ee1878ad30a5cbfee95f0f630' "$BLOCKS" ||
  fail 'upstream design provenance missing'

mkdir -p "$TMP/bin" "$TMP/state/i3" "$TMP/proc/net" \
  "$TMP/sys/class/power_supply/CMB0" "$TMP/sys/class/net/wlan-test/wireless" \
  "$TMP/sys/class/thermal/thermal_zone0"
cat >"$TMP/bin/pamixer" <<'STUB'
#!/usr/bin/env bash
case " $* " in
  *' --get-mute '*) printf '%s\n' "${MUTED:-false}" ;;
  *' --get-volume '*) printf '%s\n' "${VOLUME:-47}" ;;
  *) printf '%s\n' "$*" >>"${ACTION_LOG:-/dev/null}" ;;
esac
STUB
cat >"$TMP/bin/xkb-switch" <<'STUB'
#!/usr/bin/env bash
printf 'latam\n'
STUB
cat >"$TMP/bin/brightnessctl" <<'STUB'
#!/usr/bin/env bash
if [[ "${1:-}" == -m ]]; then
  printf 'backlight,intel_backlight,1200,60%%,2000\n'
else
  printf '%s\n' "$*" >>"${ACTION_LOG:-/dev/null}"
fi
STUB
cat >"$TMP/bin/i3-caffeine-toggle" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${ACTION_LOG:-/dev/null}"
STUB
cat >"$TMP/bin/i3-msg" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${ACTION_LOG:-/dev/null}"
STUB
cat >"$TMP/bin/ip" <<'STUB'
#!/usr/bin/env bash
case "$*" in
  'route show default') [[ "${NETWORK_OFFLINE:-0}" == 1 ]] || printf 'default via 192.0.2.1 dev wlan-test\n' ;;
  '-4 -o addr show dev wlan-test scope global') printf '2: wlan-test inet 192.0.2.5/24 scope global\n' ;;
esac
STUB
cat >"$TMP/bin/nmcli" <<'STUB'
#!/usr/bin/env bash
printf 'Cafe & <Lab>\n'
STUB
cat >"$TMP/bin/xclip" <<'STUB'
#!/usr/bin/env bash
cat >"${CLIPBOARD_LOG:-/dev/null}"
STUB
cat >"$TMP/bin/df" <<'STUB'
#!/usr/bin/env bash
printf 'Filesystem Size Used Avail Use%% Mounted on\n/dev/test 100G 25G 75G 25%% /\n'
STUB
cat >"$TMP/bin/date" <<'STUB'
#!/usr/bin/env bash
case "${1:-}" in
  '+%A %d/%m/%Y') printf 'miércoles 22/07/2026\n' ;;
  '+%I:%M %p') printf '04:30 PM\n' ;;
esac
STUB
cat >"$TMP/bin/sleep" <<'STUB'
#!/usr/bin/env bash
if [[ -n "${CPU_STAT_FILE:-}" ]]; then
  printf 'cpu  200 0 200 900 0 0 0 0 0 0\n' >"$CPU_STAT_FILE"
fi
STUB
chmod +x "$TMP/bin/"*
cat >"$TMP/proc/meminfo" <<'DATA'
MemTotal:        8000000 kB
MemAvailable:   2000000 kB
DATA
cat >"$TMP/proc/stat" <<'DATA'
cpu  100 0 100 800 0 0 0 0 0 0
DATA
printf 'Battery\n' >"$TMP/sys/class/power_supply/CMB0/type"
printf '73\n' >"$TMP/sys/class/power_supply/CMB0/capacity"
printf 'Discharging\n' >"$TMP/sys/class/power_supply/CMB0/status"
printf 'wlan-test: 0000 49.0 -61.0 -256 0 0 0 0 0 0\n' >"$TMP/proc/net/wireless"
printf '86000\n' >"$TMP/sys/class/thermal/thermal_zone0/temp"

run_block() {
  PATH="$TMP/bin:$PATH" XDG_STATE_HOME="$TMP/state" I3BLOCKS_PROC_ROOT="$TMP/proc" \
    I3BLOCKS_SYS_ROOT="$TMP/sys" ACTION_LOG="$TMP/actions" "$HELPER" "$1"
}

[[ "$(run_block language | head -n1)" == LATAM ]] || fail 'language block output incorrect'
[[ "$(run_block brightness | head -n1)" == '60%' ]] || fail 'brightness block output incorrect'
[[ "$(run_block memory | head -n1)" == '5.7G' ]] || fail 'memory block output incorrect'
[[ "$(run_block battery | head -n1)" == *'73%'* ]] || fail 'non-BAT battery discovery failed'
[[ "$(run_block disk | head -n1)" == '75G' ]] || fail 'disk block output incorrect'
[[ "$(run_block network | head -n1)" == '  Cafe &amp; &lt;Lab&gt; 70%' ]] ||
  fail 'network output is not portable and Pango-safe'
[[ "$(run_block temperature | head -n1)" == '86°C' ]] || fail 'temperature block output incorrect'
[[ "$(CPU_STAT_FILE="$TMP/proc/stat" run_block cpu | head -n1)" == '67%' ]] || fail 'CPU block output incorrect'
[[ "$(run_block time | head -n1)" == '  miércoles 22/07/2026    04:30 PM' ]] ||
  fail 'time block output incorrect'
[[ "$(VOLUME=47 run_block volume | head -n1)" == '47%' ]] || fail 'volume block output incorrect'
[[ "$(VOLUME=47 run_block microphone | head -n1)" == '47%' ]] || fail 'microphone block output incorrect'
[[ "$(MUTED=true run_block volume | head -n1)" == MUTE ]] || fail 'muted volume output incorrect'

: >"$TMP/actions"
BLOCK_BUTTON=1 run_block caffeine >/dev/null
grep -Fxq 'toggle' "$TMP/actions" || fail 'caffeine click does not toggle state'
: >"$TMP/actions"
BLOCK_BUTTON=4 run_block brightness >/dev/null
grep -Fxq 'set 5%+' "$TMP/actions" || fail 'brightness scroll-up action missing'
: >"$TMP/actions"
BLOCK_BUTTON=4 run_block volume >/dev/null
grep -Fxq -- '--allow-boost --set-limit 150 -i 3' "$TMP/actions" || fail 'volume scroll-up action missing'
: >"$TMP/actions"
BLOCK_BUTTON=3 run_block microphone >/dev/null
grep -Fxq -- '--default-source -t' "$TMP/actions" || fail 'microphone mute action missing'
: >"$TMP/actions"
NETWORK_OFFLINE=1 BLOCK_BUTTON=1 run_block network >/dev/null
grep -Fxq 'exec --no-startup-id nm-connection-editor' "$TMP/actions" ||
  fail 'offline network click does not open connection editor'
: >"$TMP/actions"
BLOCK_BUTTON=1 run_block time >/dev/null
grep -Fxq 'exec --no-startup-id gsimplecal' "$TMP/actions" || fail 'calendar click action missing'

printf 'PASS: portable krasiyan-inspired i3blocks status replaces Bumblebee\n'
