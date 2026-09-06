#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="${ORGM_THEMES_BIN:-orgm-themes}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/config/orgm-theme/themes" "$TMP/state" "$TMP/runtime" "$TMP/bin"
cp "$ROOT/config/profiles/hyprland/.config/orgm-theme/themes/orgm-light.env" "$TMP/config/orgm-theme/themes/orgm-light.env"
cp "$ROOT/config/profiles/hyprland/.config/orgm-theme/themes/orgm-dark.env" "$TMP/config/orgm-theme/themes/orgm-dark.env"

for bin in hyprctl hypr-wallpaper kitty swaync-client nautilus systemctl waybar-watch; do
  cat >"$TMP/bin/$bin" <<'SH'
#!/usr/bin/env bash
exit 0
SH
  chmod +x "$TMP/bin/$bin"
done

cat >"$TMP/bin/gsettings" <<'SH'
#!/usr/bin/env bash
echo "gsettings $*" >>"$GSETTINGS_LOG"
SH
chmod +x "$TMP/bin/gsettings"
: >"$TMP/gsettings.log"

HOME="$TMP/home" \
XDG_CONFIG_HOME="$TMP/config" \
XDG_STATE_HOME="$TMP/state" \
XDG_RUNTIME_DIR="$TMP/runtime" \
PATH="$TMP/bin:$PATH" \
GSETTINGS_LOG="$TMP/gsettings.log" \
"$SCRIPT" apply orgm-light >"$TMP/apply.out"

for settings in "$TMP/config/gtk-3.0/settings.ini" "$TMP/config/gtk-4.0/settings.ini"; do
  if [ -e "$settings" ]; then
    echo "FAIL: orgm-themes must leave GTK preferences runtime-owned: $settings" >&2
    exit 1
  fi
done

if [ -s "$TMP/gsettings.log" ]; then
  echo "FAIL: orgm-themes must not mutate system gsettings during dark/light preset switch" >&2
  cat "$TMP/gsettings.log" >&2
  exit 1
fi

python3 - \
  "$TMP/config/waybar-hypr/orgm-current.css" \
  "$TMP/config/swaync/orgm-current.css" \
  "$TMP/config/gtk-4.0/gtk.css" <<'PY'
import re
import sys

HEX = re.compile(r"^#([0-9a-fA-F]{6})$")
RGBA = re.compile(r"^rgba\((\d+),\s*(\d+),\s*(\d+),\s*(0(?:\.\d+)?|1(?:\.0+)?)\)$")
DEFINE = re.compile(r"^@define-color\s+(\w+)\s+(.+);$")


def fail(message):
    print(f"FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def parse_color(value):
    if match := HEX.fullmatch(value):
        digits = match.group(1)
        return tuple(int(digits[index:index + 2], 16) / 255 for index in (0, 2, 4)) + (1.0,)
    if match := RGBA.fullmatch(value):
        red, green, blue, alpha = match.groups()
        channels = tuple(int(channel) / 255 for channel in (red, green, blue))
        if any(channel > 1 for channel in channels):
            fail(f"invalid rgb channel in {value}")
        return channels + (float(alpha),)
    fail(f"unsupported generated CSS color {value!r}")


def luminance(color):
    def linear(channel):
        return channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4

    red, green, blue = (linear(channel) for channel in color[:3])
    return 0.2126 * red + 0.7152 * green + 0.0722 * blue


def opaque(color, background):
    red, green, blue, alpha = color
    return tuple(channel * alpha + backdrop * (1 - alpha) for channel, backdrop in zip((red, green, blue), background))


def contrast(foreground, background):
    foreground_luminance = luminance(foreground)
    background_luminance = luminance(background)
    lighter, darker = sorted((foreground_luminance, background_luminance), reverse=True)
    return (lighter + 0.05) / (darker + 0.05)


def palette(path):
    content = open(path, encoding="utf-8").read()
    if re.search(r"#[0-9a-fA-F]{8}\b", content):
        fail(f"{path} uses unsafe eight-digit hex CSS colors")
    colors = {}
    for line in content.splitlines():
        if match := DEFINE.fullmatch(line):
            colors[match.group(1)] = match.group(2)
    return colors


waybar_path, swaync_path, gtk_path = sys.argv[1:]
waybar = palette(waybar_path)
swaync = palette(swaync_path)
gtk = palette(gtk_path)

for path, colors, names in (
    (waybar_path, waybar, ("base", "text", "panel_bg", "panel_border")),
    (swaync_path, swaync, ("base", "text", "panel_bg", "swaync_bg")),
    (gtk_path, gtk, ("window_bg_color", "window_fg_color")),
):
    missing = set(names) - colors.keys()
    if missing:
        fail(f"{path} is missing generated colors: {', '.join(sorted(missing))}")
    for name in names:
        parse_color(colors[name])

waybar_base = parse_color(waybar["base"])[:3]
swaync_base = parse_color(swaync["base"])[:3]
waybar_text = parse_color(waybar["text"])
swaync_text = parse_color(swaync["text"])
gtk_window_foreground = parse_color(gtk["window_fg_color"])
gtk_window_background = parse_color(gtk["window_bg_color"])
if luminance(waybar_base) <= luminance(waybar_text):
    fail("Waybar light palette does not render dark text on a light surface")
if contrast(waybar_text, opaque(parse_color(waybar["panel_bg"]), waybar_base)) < 4.5:
    fail("Waybar text lacks WCAG AA contrast against its panel")
if contrast(swaync_text, opaque(parse_color(swaync["swaync_bg"]), swaync_base)) < 4.5:
    fail("SwayNC text lacks WCAG AA contrast against its notification surface")
if contrast(gtk_window_foreground, gtk_window_background) < 4.5:
    fail("GTK window text lacks WCAG AA contrast")
PY

echo "orgm-theme light contrast smoke test passed"
