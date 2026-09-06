#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="${ORGM_THEMES_BIN:-orgm-themes}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

CALLS="$TMP/calls.log"
export CALLS

mkdir -p "$TMP/bin" "$TMP/config/orgm-theme/themes" "$TMP/state/hypr-wallpaper/monitors" "$TMP/state/orgm-theme/wallpapers" "$TMP/runtime"

cat >"$TMP/bin/hypr-wallpaper" <<'SH'
#!/usr/bin/env bash
echo "hypr-wallpaper $*" >>"$CALLS"
SH
chmod +x "$TMP/bin/hypr-wallpaper"

cat >"$TMP/bin/hyprctl" <<'SH'
#!/usr/bin/env bash
echo "hyprctl $*" >>"$CALLS"
SH
chmod +x "$TMP/bin/hyprctl"

for bin in kitty swaync-client nautilus systemctl waybar-watch gsettings; do
  cat >"$TMP/bin/$bin" <<'SH'
#!/usr/bin/env bash
exit 0
SH
  chmod +x "$TMP/bin/$bin"
done

cat >"$TMP/config/orgm-theme/themes/orgm-dark.env" <<'EOF'
THEME_NAME=orgm-dark
COLOR_SCHEME=prefer-dark
GTK_THEME=Adwaita-dark
ICON_THEME=Adwaita
CURSOR_THEME=Catppuccin-Macchiato-Teal-Cursors
CURSOR_SIZE=36
QT_STYLE=Darkly
PI_THEME=orgm
BASE=24273a
MANTLE=1e2030
CRUST=181926
TEXT=cad3f5
SUBTEXT0=a5adcb
SUBTEXT1=b8c0e0
SURFACE0=363a4f
SURFACE1=494d64
SURFACE2=5b6078
OVERLAY0=6e738d
OVERLAY1=8087a2
OVERLAY2=939ab7
BLUE=8aadf4
GREEN=a6da95
YELLOW=eed49f
PEACH=f5a97f
RED=ed8796
MAUVE=c6a0f6
PINK=f5bde6
TEAL=8bd5ca
SKY=91d7e3
ROSEWATER=f4dbd6
PANEL_BG=00000099
MENU_BG=000000dd
QS_OVERLAY=e611111b
QS_CARD=22363a4f
QS_CARD_STRONG=33494d64
QS_CARD_SOFT=1e363a4f
QS_EVENT=2b363a4f
QS_HOVER=55363a4f
ON_ACCENT=11111b
EOF

cat >"$TMP/config/orgm-theme/themes/orgm-light.env" <<'EOF'
THEME_NAME=orgm-light
COLOR_SCHEME=prefer-light
GTK_THEME=Adwaita
ICON_THEME=Adwaita
CURSOR_THEME=Catppuccin-Latte-Teal-Cursors
CURSOR_SIZE=36
QT_STYLE=Fusion
PI_THEME=orgm-light
BASE=eff1f5
MANTLE=e6e9ef
CRUST=dce0e8
TEXT=4c4f69
SUBTEXT0=6c6f85
SUBTEXT1=5c5f77
SURFACE0=ccd0da
SURFACE1=bcc0cc
SURFACE2=acb0be
OVERLAY0=9ca0b0
OVERLAY1=8c8fa1
OVERLAY2=7c7f93
BLUE=1e66f5
GREEN=40a02b
YELLOW=df8e1d
PEACH=fe640b
RED=d20f39
MAUVE=8839ef
PINK=ea76cb
TEAL=179299
SKY=04a5e5
ROSEWATER=dc8a78
PANEL_BG=eff1f5dd
MENU_BG=eff1f5ee
QS_OVERLAY=eef8f9fc
QS_CARD=e6e9efcc
QS_CARD_STRONG=ccd0dacc
QS_CARD_SOFT=dce0e8cc
QS_EVENT=eff1f5ee
QS_HOVER=bcc0ccaa
ON_ACCENT=eff1f5
EOF

mkdir -p "$TMP/state/orgm-theme/wallpapers/orgm-light.monitors"
printf 'orgm-dark\n' >"$TMP/state/orgm-theme/current"
printf '/wallpapers/dark.png\n' >"$TMP/state/hypr-wallpaper/current"
printf 'mode=static\npath=/wallpapers/dark-dp.png\n' >"$TMP/state/hypr-wallpaper/monitors/DP-1.state"
printf 'mode=video\npath=/wallpapers/dark-edp.mp4\n' >"$TMP/state/hypr-wallpaper/monitors/eDP-1.state"
printf 'path=/wallpapers/light.png\n' >"$TMP/state/orgm-theme/wallpapers/orgm-light.state"
printf 'mode=static\npath=/wallpapers/light-dp.png\n' >"$TMP/state/orgm-theme/wallpapers/orgm-light.monitors/DP-1.state"
printf 'mode=video\npath=/wallpapers/light-edp.mp4\n' >"$TMP/state/orgm-theme/wallpapers/orgm-light.monitors/eDP-1.state"

HOME="$TMP/home" \
XDG_CONFIG_HOME="$TMP/config" \
XDG_STATE_HOME="$TMP/state" \
XDG_RUNTIME_DIR="$TMP/runtime" \
PATH="$TMP/bin:$PATH" \
"$SCRIPT" apply orgm-light >/tmp/orgm-theme-wallpaper.out

grep -q '^path=/wallpapers/dark.png$' "$TMP/state/orgm-theme/wallpapers/orgm-dark.state" || {
  echo "FAIL: outgoing dark global wallpaper path was not saved" >&2
  cat "$TMP/state/orgm-theme/wallpapers/orgm-dark.state" >&2 || true
  exit 1
}

grep -qx 'mode=static' "$TMP/state/orgm-theme/wallpapers/orgm-dark.monitors/DP-1.state" &&
  grep -qx 'path=/wallpapers/dark-dp.png' "$TMP/state/orgm-theme/wallpapers/orgm-dark.monitors/DP-1.state" || {
  echo "FAIL: outgoing dark DP-1 wallpaper snapshot was not saved" >&2
  exit 1
}
grep -qx 'mode=video' "$TMP/state/orgm-theme/wallpapers/orgm-dark.monitors/eDP-1.state" &&
  grep -qx 'path=/wallpapers/dark-edp.mp4' "$TMP/state/orgm-theme/wallpapers/orgm-dark.monitors/eDP-1.state" || {
  echo "FAIL: outgoing dark eDP-1 wallpaper snapshot was not saved" >&2
  exit 1
}

expected_calls=$'hyprctl reload\nhypr-wallpaper set /wallpapers/light.png\nhypr-wallpaper set /wallpapers/light-dp.png --monitor DP-1\nhypr-wallpaper set /wallpapers/light-edp.mp4 --monitor eDP-1'
if [ "$(cat "$CALLS")" != "$expected_calls" ]; then
  echo "FAIL: reload must precede global and per-monitor wallpaper restoration via hypr-wallpaper" >&2
  cat "$CALLS" >&2
  exit 1
fi

echo "orgm-theme wallpaper memory smoke test passed"
