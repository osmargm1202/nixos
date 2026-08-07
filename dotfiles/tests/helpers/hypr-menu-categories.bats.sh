#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail() {
	echo "FAIL: $*" >&2
	exit 1
}
assert_contains() { grep -Fq "$2" "$1" || fail "expected $2 in $1"; }
assert_not_contains() { ! grep -Fq "$2" "$1" || fail "did not expect $2 in $1"; }

BIN="$ROOT/config/profiles/hyprland/.local/bin"
KEYS="$ROOT/config/profiles/hyprland/.config/hypr/lua/keybindings.lua"
MAIN="$BIN/hypr-main-menu"
TOOLS="$BIN/hypr-tools-menu"
SYSTEM="$BIN/hypr-system-menu"
PERF="$BIN/hypr-performance-menu"
TWEAKS="$BIN/hypr-tweaks-menu"
DEVICES="$BIN/hypr-devices-menu"
HELP="$BIN/hypr-help-menu"

for script in "$MAIN" "$TOOLS" "$SYSTEM" "$PERF" "$TWEAKS" "$DEVICES" "$HELP"; do
	[[ -x "$script" ]] || fail "script not executable: $script"
	bash -n "$script"
done

# Central menu is category-first.
assert_contains "$MAIN" '󰀻 Apps'
assert_contains "$MAIN" '󰒓 Tools'
assert_contains "$MAIN" '󰔎 Tweaks'
assert_contains "$MAIN" '󰖩 Devices'
assert_contains "$MAIN" '󰍛 Performance / Cleanup'
assert_contains "$MAIN" '󰒓 System'
assert_contains "$MAIN" '󰌌 Help'
assert_contains "$MAIN" 'hypr-tweaks-menu'
assert_contains "$MAIN" 'hypr-devices-menu'
assert_contains "$MAIN" 'hypr-help-menu'

# Waybar custom buttons are reachable from categorized rofi menus.
assert_contains "$TOOLS" 'hypr-rofi-clipboard'
assert_contains "$TOOLS" 'hypr-config-editor'
assert_contains "$TWEAKS" 'skwd wall toggle'
assert_not_contains "$TWEAKS" 'hypr-random-wallpaper'
assert_not_contains "$TWEAKS" 'hypr-wallpaper-picker'
assert_contains "$TWEAKS" 'kbd-layout-next'
assert_contains "$KEYS" 'mainMod .. " + ALT + W", hl.dsp.exec_cmd("skwd wall toggle")'
assert_contains "$KEYS" 'mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("firefox")'
assert_not_contains "$KEYS" 'hypr-wallpaper-picker'
assert_contains "$DEVICES" 'hypr-usb-menu open'
assert_contains "$DEVICES" 'hypr-usb-menu nickname'
assert_contains "$DEVICES" 'hypr-bluetooth-reconnect'
assert_contains "$DEVICES" 'hypr-display-targets'
assert_contains "$PERF" 'memclean-dev clean'
assert_contains "$PERF" 'memclean-dev dry-run'
assert_contains "$PERF" 'nixclean'
assert_contains "$PERF" 'fastfetch --config ~/.config/fastfetch/hardware.jsonc'
assert_contains "$PERF" 'pi update'
assert_contains "$HELP" 'hypr-keybindings-help'
assert_not_contains "$HELP" 'hypr-keyhelper init'
assert_contains "$SYSTEM" 'hypr-power-menu'

# Hypr menus must not escape to host.
for script in "$BIN"/hypr-*; do
	assert_not_contains "$script" 'distrobox-host-exec'
done

# Profile scripts are managed by the NixOS dotfile module.
DOTFILES_NIX="$ROOT/../nixos/common-dotfiles.nix"
assert_contains "$DOTFILES_NIX" '".local/bin/hypr-tweaks-menu"'
assert_contains "$DOTFILES_NIX" '".local/bin/hypr-devices-menu"'
assert_contains "$DOTFILES_NIX" '".local/bin/hypr-help-menu"'

for legacy in \
  "$BIN/hypr-random-wallpaper" \
  "$BIN/hypr-wallpaper-picker" \
  "$BIN/hypr-wallpaper-picker-dark" \
  "$BIN/hypr-wallpaper-picker-light" \
  "$ROOT/config/profiles/hyprland/.config/hypr/wallpaper-picker/README.md" \
  "$ROOT/config/profiles/hyprland/.config/hypr/wallpaper-picker/wallpaper_picker.py" \
  "$ROOT/config/profiles/hyprland/.config/quickshell/wallpaper-picker/shell.qml"; do
  [ ! -e "$legacy" ] || fail "legacy wallpaper file remains: $legacy"
done

classic_paths="$(awk '/^    hyprland = \[/,/^    \];/' "$DOTFILES_NIX")"
if printf '%s\n' "$classic_paths" | rg -q 'waytrogen|hypr-random-wallpaper|hypr-wallpaper-picker'; then
  fail "classic Hyprland dotfile registrations still contain legacy wallpaper paths"
fi

echo "hypr menu categories test passed"
