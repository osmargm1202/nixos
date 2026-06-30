#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail() { echo "FAIL: $*" >&2; exit 1; }
assert_contains() { grep -Fq "$2" "$1" || fail "expected $2 in $1"; }
assert_not_contains() { ! grep -Fq "$2" "$1" || fail "did not expect $2 in $1"; }

BIN="$ROOT/config/shared/.local/bin"
MAIN="$BIN/hypr-main-menu"
TOOLS="$BIN/hypr-tools-menu"
SYSTEM="$BIN/hypr-system-menu"
PERF="$BIN/hypr-performance-menu"
TWEAKS="$BIN/hypr-tweaks-menu"
DEVICES="$BIN/hypr-devices-menu"
HELP="$BIN/hypr-help-menu"
ORGMDOT="$BIN/hypr-orgm-dot"

for script in "$MAIN" "$TOOLS" "$SYSTEM" "$PERF" "$TWEAKS" "$DEVICES" "$HELP" "$ORGMDOT"; do
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
assert_contains "$TWEAKS" 'waybar-theme-toggle toggle'
assert_contains "$TWEAKS" 'orgm-wallpaper random-static'
assert_contains "$TWEAKS" 'orgm-wallpaper pick'
assert_contains "$TWEAKS" 'kbd-layout-next'
assert_contains "$DEVICES" 'hypr-usb-menu open'
assert_contains "$DEVICES" 'hypr-usb-menu nickname'
assert_contains "$DEVICES" 'hypr-bluetooth-reconnect'
assert_contains "$DEVICES" 'hypr-display-targets'
assert_contains "$PERF" 'memclean-dev clean'
assert_contains "$PERF" 'memclean-dev dry-run'
assert_contains "$PERF" 'nixclean'
assert_contains "$PERF" 'fastfetch --config ~/.config/fastfetch/hardware.jsonc'
assert_contains "$PERF" 'pi update'
assert_contains "$HELP" 'hypr-keyhelper toggle'
assert_contains "$HELP" 'hypr-keyhelper init'
assert_contains "$HELP" 'hypr-keybindings-help'
assert_contains "$SYSTEM" 'hypr-power-menu'

# Hypr menus must not escape to host. orgm-dot runs direct/fallback local, not distrobox-host-exec.
for script in "$BIN"/hypr-*; do
  assert_not_contains "$script" 'distrobox-host-exec'
done
assert_contains "$ORGMDOT" 'orgm-dot'
assert_contains "$ORGMDOT" 'go run ./cmd/orgm-dot'
assert_contains "$SYSTEM" 'hypr-orgm-dot status'
assert_contains "$SYSTEM" 'hypr-orgm-dot diff'
assert_contains "$SYSTEM" 'hypr-orgm-dot sync'

# New scripts are managed by dotfiles config.
assert_contains "$ROOT/config/dotfiles.json" '".local/bin/hypr-tweaks-menu"'
assert_contains "$ROOT/config/dotfiles.json" '".local/bin/hypr-devices-menu"'
assert_contains "$ROOT/config/dotfiles.json" '".local/bin/hypr-help-menu"'
assert_contains "$ROOT/config/dotfiles.json" '".local/bin/hypr-orgm-dot"'

echo "hypr menu categories test passed"
