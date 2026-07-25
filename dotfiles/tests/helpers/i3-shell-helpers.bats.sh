#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
I3="$ROOT/config/profiles/i3/.config/i3/config"
ROFI="$ROOT/config/profiles/i3/.config/rofi/config.rasi"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

grep -Fq 'exec_always --no-startup-id $run i3-polybar start' "$I3" ||
  fail 'Polybar launcher missing'
grep -Fq 'exec --no-startup-id $run i3-monitor-profile --apply' "$I3" || fail 'serialized monitor/wallpaper restore missing'
grep -q 'exec --no-startup-id clipmenud' "$I3" || fail 'clipmenud missing'
grep -q 'exec --no-startup-id xss-lock.*i3-lock --nofork' "$I3" || fail 'xss-lock must keep themed locker in foreground'
! grep -Eq 'hypr-|xwinwrap|Videos/wallpapers/1\.mp4' "$I3" || fail 'nonportable command remains'
grep -q 'terminal: "kitty"' "$ROFI" || fail 'Rofi terminal is not Kitty'
grep -q 'modi: "drun,run,window,ssh,calc"' "$ROFI" || fail 'Rofi modes incomplete'
grep -Fq 'bindsym $mod+g layout tabbed' "$I3" || fail 'grouped tabs binding missing'
grep -Fq 'bindsym $mod+Shift+g layout default' "$I3" || fail 'normal layout binding missing'
! grep -Eq 'scratchpad|layout stacking' "$I3" || fail 'removed scratchpad/stacking binding remains'

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
  i3-wallpaper
  i3-hotkeys
  i3-config-editor
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
for command in systemctl i3-msg setxkbmap xkb-switch xrandr feh; do
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
grep -Fxq 'xkb-switch -s latam' "$TMP/keyboard.calls" || fail 'Latam action incorrect'

mkdir -p "$TMP/state/i3" "$TMP/wallpapers"
printf 'image\n' > "$TMP/wallpapers/current.png"
printf '%s\n' "$TMP/wallpapers/current.png" > "$TMP/state/i3/wallpaper"
CALLS="$TMP/wallpaper.calls" HOME="$TMP/home" XDG_STATE_HOME="$TMP/state" I3_WALLPAPER_DIR="$TMP/wallpapers" PATH="$TMP/bin:$PATH" "$BIN/i3-wallpaper" --restore
grep -Fxq "feh --bg-fill $TMP/wallpapers/current.png" "$TMP/wallpaper.calls" || fail 'wallpaper restore incorrect'

CALLS="$TMP/profile.calls" ROFI_CHOICE=Balanced ROFI_INPUT="$TMP/profile-menu" PATH="$TMP/bin:$PATH" "$BIN/i3-performance-menu"
grep -Fxq 'powerprofilesctl set balanced' "$TMP/profile.calls" || fail 'Balanced profile action incorrect'
grep -Fxq 'Balanced' "$TMP/profile-menu" || fail 'available Balanced profile missing'
! grep -Fxq 'Performance' "$TMP/profile-menu" || fail 'unavailable Performance profile was offered'

printf 'PASS: i3 shell helper tests\n'
