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
grep -q 'scratchpad show' "$I3" || fail 'scratchpad show binding missing'
grep -q 'move scratchpad' "$I3" || fail 'scratchpad move binding missing'

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

cat > "$TMP/bin/i3-rofi" <<'STUB'
#!/usr/bin/env bash
[[ "${ROFI_CANCEL:-0}" == 0 ]] || exit 1
if [[ -n "${ROFI_INPUT:-}" ]]; then
  cat > "$ROFI_INPUT"
else
  cat >/dev/null
fi
printf '%s\n' "${ROFI_CHOICE:-}"
STUB
for command in systemctl i3-msg setxkbmap feh polybar polybar-msg; do
  cat > "$TMP/bin/$command" <<'STUB'
#!/usr/bin/env bash
printf '%s %s\n' "$(basename "$0")" "$*" >> "$CALLS"
STUB
done
cat > "$TMP/bin/powerprofilesctl" <<'STUB'
#!/usr/bin/env bash
printf 'powerprofilesctl %s\n' "$*" >> "$CALLS"
if [[ "${1:-}" == list ]]; then
  printf '%s\n' '* balanced:' '  power-saver:'
fi
STUB
cat > "$TMP/bin/pgrep" <<'STUB'
#!/usr/bin/env bash
exit 1
STUB
chmod +x "$TMP/bin/"*

CALLS="$TMP/cancel.calls" ROFI_CANCEL=1 PATH="$TMP/bin:$PATH" "$BIN/i3-powermenu"
[[ ! -s "$TMP/cancel.calls" ]] || fail 'cancelled power menu caused action'

CALLS="$TMP/suspend.calls" ROFI_CHOICE=Suspend PATH="$TMP/bin:$PATH" "$BIN/i3-powermenu"
grep -Fxq 'systemctl suspend' "$TMP/suspend.calls" || fail 'Suspend action incorrect'

CALLS="$TMP/logout.calls" ROFI_CHOICE=Logout PATH="$TMP/bin:$PATH" "$BIN/i3-powermenu"
grep -Fxq 'i3-msg exit' "$TMP/logout.calls" || fail 'Logout action incorrect'

CALLS="$TMP/keyboard.calls" ROFI_CHOICE=Latam PATH="$TMP/bin:$PATH" "$BIN/i3-keyboard-menu"
grep -Fxq 'setxkbmap -layout latam' "$TMP/keyboard.calls" || fail 'Latam action incorrect'

mkdir -p "$TMP/state/i3" "$TMP/wallpapers"
printf 'image\n' > "$TMP/wallpapers/current.png"
printf '%s\n' "$TMP/wallpapers/current.png" > "$TMP/state/i3/wallpaper"
CALLS="$TMP/wallpaper.calls" XDG_STATE_HOME="$TMP/state" I3_WALLPAPER_DIR="$TMP/wallpapers" PATH="$TMP/bin:$PATH" "$BIN/i3-wallpaper-random" --restore
grep -Fxq "feh --no-fehbg --bg-fill $TMP/wallpapers/current.png" "$TMP/wallpaper.calls" || fail 'wallpaper restore incorrect'

CALLS="$TMP/profile.calls" ROFI_CHOICE=Balanced ROFI_INPUT="$TMP/profile-menu" PATH="$TMP/bin:$PATH" "$BIN/i3-performance-menu"
grep -Fxq 'powerprofilesctl set balanced' "$TMP/profile.calls" || fail 'Balanced profile action incorrect'
grep -Fxq 'Balanced' "$TMP/profile-menu" || fail 'available Balanced profile missing'
! grep -Fxq 'Performance' "$TMP/profile-menu" || fail 'unavailable Performance profile was offered'

CALLS="$TMP/polybar.calls" HOME="$TMP/home" PATH="$TMP/bin:$PATH" "$BIN/i3-polybar-launch"
first="$(sed -n '1p' "$TMP/polybar.calls")"
second="$(sed -n '2p' "$TMP/polybar.calls")"
[[ "$first" == 'polybar-msg cmd quit' ]] || fail 'Polybar old process was not stopped first'
[[ "$second" == "polybar --config=$TMP/home/.config/polybar/config.ini modern" ]] || fail 'Polybar launch action incorrect'

printf 'PASS: i3 shell helper tests\n'
