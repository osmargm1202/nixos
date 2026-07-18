#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
I3="$ROOT/config/profiles/i3/.config/i3/config"
ROFI="$ROOT/config/profiles/i3/.config/rofi/config.rasi"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

grep -q 'exec --no-startup-id i3-polybar-launch' "$I3" || fail 'polybar launcher missing'
grep -q 'exec --no-startup-id i3-wallpaper-random --restore' "$I3" || fail 'wallpaper restore missing'
grep -q 'exec --no-startup-id clipmenud' "$I3" || fail 'clipmenud missing'
grep -q 'exec --no-startup-id xss-lock.*i3lock-color --nofork' "$I3" || fail 'xss-lock must keep locker in foreground'
! grep -Eq 'hypr-|xwinwrap|Videos/wallpapers/1\.mp4' "$I3" || fail 'nonportable command remains'
grep -q 'terminal: "kitty"' "$ROFI" || fail 'Rofi terminal is not Kitty'
grep -q 'modi: "drun,run,window,ssh,calc"' "$ROFI" || fail 'Rofi modes incomplete'

BIN="$ROOT/config/profiles/i3/.local/bin"
helpers=(
  i3-rofi
  i3-open-file
  i3-clipboard
  i3-ssh-host
  i3-main-menu
  i3-powermenu
  i3-performance-menu
  i3-keyboard-menu
  i3-wallpaper-random
  i3-hotkeys
  i3-config-editor
  i3-polybar-launch
  i3-status-battery
  i3-status-cpu-temp
  i3-status-gpu-temp
)
for helper in "${helpers[@]}"; do
  [[ -x "$BIN/$helper" ]] || fail "$helper missing or not executable"
  bash -n "$BIN/$helper" || fail "$helper syntax"
  ! grep -Eq 'hypr-|hyprctl' "$BIN/$helper" || fail "$helper depends on Hyprland"
done

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/files/visible" "$TMP/files/.hidden"
printf 'ok\n' > "$TMP/files/visible/file.txt"
printf 'secret\n' > "$TMP/files/.hidden/file.txt"
cat > "$TMP/bin/i3-rofi" <<'STUB'
#!/usr/bin/env bash
cat > "$ROFI_INPUT"
exit 1
STUB
chmod +x "$TMP/bin/i3-rofi"
ROFI_INPUT="$TMP/rofi-input" I3_FILE_ROOT="$TMP/files" PATH="$TMP/bin:$PATH" "$BIN/i3-open-file" open

grep -q 'visible/file.txt' "$TMP/rofi-input" || fail 'visible file missing from picker'
! grep -q '.hidden/file.txt' "$TMP/rofi-input" || fail 'hidden file leaked into picker'

mkdir -p "$TMP/power/BAT1" "$TMP/hwmon/hwmon0" "$TMP/empty"
printf 'Battery\n' > "$TMP/power/BAT1/type"
printf '73\n' > "$TMP/power/BAT1/capacity"
printf 'Discharging\n' > "$TMP/power/BAT1/status"
printf 'coretemp\n' > "$TMP/hwmon/hwmon0/name"
printf '56000\n' > "$TMP/hwmon/hwmon0/temp1_input"

battery="$(I3_POWER_SUPPLY_ROOT="$TMP/power" "$BIN/i3-status-battery")"
[[ "$battery" == *73%* ]] || fail 'BAT1 was not auto-detected'
cpu="$(I3_HWMON_ROOT="$TMP/hwmon" "$BIN/i3-status-cpu-temp")"
[[ "$cpu" == *56* ]] || fail 'CPU temperature not detected'
mkdir -p "$TMP/gpu-only/hwmon0"
printf 'amdgpu\n' > "$TMP/gpu-only/hwmon0/name"
printf '67000\n' > "$TMP/gpu-only/hwmon0/temp1_input"
[[ -z "$(I3_HWMON_ROOT="$TMP/gpu-only" "$BIN/i3-status-cpu-temp")" ]] || fail 'GPU sensor was mislabeled as CPU'
[[ -z "$(I3_POWER_SUPPLY_ROOT="$TMP/empty" "$BIN/i3-status-battery")" ]] || fail 'desktop battery output must be empty'

printf 'PASS: i3 shell helper tests\n'
