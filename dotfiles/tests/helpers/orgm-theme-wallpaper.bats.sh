#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="${ORGM_THEMES_BIN:-orgm-themes}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

CALLS="$TMP/calls.log"
export CALLS

mkdir -p "$TMP/bin" "$TMP/config/orgm-theme/themes" "$TMP/state/hypr-wallpaper/monitors" "$TMP/state/orgm-theme/wallpapers/orgm-light.monitors" "$TMP/runtime"

cat >"$TMP/bin/orgm-wallpaper" <<'SH'
#!/usr/bin/env bash
echo "orgm-wallpaper $*" >>"$CALLS"
SH
chmod +x "$TMP/bin/orgm-wallpaper"

cat >"$TMP/bin/hyprctl" <<'SH'
#!/usr/bin/env bash
echo "hyprctl $*" >>"$CALLS"
if [ "${1:-}" = reload ]; then
  echo "orgm-wallpaper random video (reload side effect)" >>"$CALLS"
fi
exit 0
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

printf 'orgm-dark\n' >"$TMP/state/orgm-theme/current"
printf 'mode=static\npath=/wallpapers/dark.png\n' >"$TMP/state/hypr-wallpaper/state"
printf 'mode=static\npath=/wallpapers/light.png\n' >"$TMP/state/orgm-theme/wallpapers/orgm-light.state"
printf 'mode=static\npath=/wallpapers/current-dp.png\n' >"$TMP/state/hypr-wallpaper/monitors/DP-3.state"
printf 'mode=static\npath=/wallpapers/light-dp.png\n' >"$TMP/state/orgm-theme/wallpapers/orgm-light.monitors/DP-3.state"
printf 'mode=static\npath=/wallpapers/light-hdmi.png\n' >"$TMP/state/orgm-theme/wallpapers/orgm-light.monitors/HDMI-A-1.state"

HOME="$TMP/home" \
XDG_CONFIG_HOME="$TMP/config" \
XDG_STATE_HOME="$TMP/state" \
XDG_RUNTIME_DIR="$TMP/runtime" \
PATH="$TMP/bin:$PATH" \
"$SCRIPT" apply orgm-light >/tmp/orgm-theme-wallpaper.out

grep -q '^mode=static$' "$TMP/state/orgm-theme/wallpapers/orgm-dark.state" || {
  echo "FAIL: outgoing dark wallpaper mode was not saved" >&2
  cat "$TMP/state/orgm-theme/wallpapers/orgm-dark.state" >&2 || true
  exit 1
}

grep -q '^path=/wallpapers/dark.png$' "$TMP/state/orgm-theme/wallpapers/orgm-dark.state" || {
  echo "FAIL: outgoing dark wallpaper path was not saved" >&2
  cat "$TMP/state/orgm-theme/wallpapers/orgm-dark.state" >&2 || true
  exit 1
}

grep -q '^mode=static$' "$TMP/state/orgm-theme/wallpapers/orgm-dark.monitors/DP-3.state" || {
  echo "FAIL: outgoing monitor wallpaper mode was not saved" >&2
  find "$TMP/state/orgm-theme/wallpapers" -type f -maxdepth 2 -print -exec cat {} \; >&2 || true
  exit 1
}

grep -q '^path=/wallpapers/current-dp.png$' "$TMP/state/orgm-theme/wallpapers/orgm-dark.monitors/DP-3.state" || {
  echo "FAIL: outgoing monitor wallpaper path was not saved" >&2
  find "$TMP/state/orgm-theme/wallpapers" -type f -maxdepth 2 -print -exec cat {} \; >&2 || true
  exit 1
}

grep -q '^orgm-wallpaper set-static /wallpapers/light-dp.png --monitor DP-3$' "$CALLS" || {
  echo "FAIL: incoming light DP monitor wallpaper was not restored" >&2
  cat "$CALLS" >&2
  exit 1
}

grep -q '^orgm-wallpaper set-static /wallpapers/light-hdmi.png --monitor HDMI-A-1$' "$CALLS" || {
  echo "FAIL: incoming light HDMI monitor wallpaper was not restored" >&2
  cat "$CALLS" >&2
  exit 1
}

last_wallpaper_call="$(grep '^orgm-wallpaper ' "$CALLS" | tail -n 1)"
if [ "$last_wallpaper_call" != 'orgm-wallpaper set-static /wallpapers/light-hdmi.png --monitor HDMI-A-1' ]; then
  echo "FAIL: incoming theme wallpaper must be restored after live reload" >&2
  cat "$CALLS" >&2
  exit 1
fi

echo "orgm-theme wallpaper memory smoke test passed"
