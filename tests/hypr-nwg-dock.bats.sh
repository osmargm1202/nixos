#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT/nixos/profiles/hyprland.nix"
AUTOSTART="$ROOT/dotfiles/config/profiles/hyprland/.config/hypr/lua/autostart.lua"
WAYBAR="$ROOT/dotfiles/config/profiles/hyprland/.config/waybar-hypr/config"
STYLE="$ROOT/dotfiles/config/profiles/hyprland/.config/nwg-dock-hyprland/style.css"
HELPER="$ROOT/dotfiles/config/profiles/hyprland/.local/bin/hypr-nwg-dock"
PINS="$ROOT/dotfiles/config/profiles/hyprland/.config/nwg-dock-hyprland/pinned"
RELOAD="$ROOT/dotfiles/config/profiles/hyprland/.local/bin/hypr-nwg-dock-reload"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

grep -Eq '^[[:space:]]+nwg-dock-hyprland[[:space:]]*$' "$PROFILE" ||
  fail 'Hyprland must install nwg-dock-hyprland'
grep -Fq '"hypr-nwg-dock",' "$AUTOSTART" ||
  fail 'Hyprland must start the dock through its pin initializer'
grep -Fq 'exec nwg-dock-hyprland' "$HELPER" ||
  fail 'Hyprland must reserve bottom space for the persistent dock'
grep -Fq -- '-c hypr-app-launcher' "$HELPER" ||
  fail 'dock launcher button must open the Rofi app launcher'
grep -Fxq 'kitty' "$PINS" && grep -Fxq 'thunar' "$PINS" &&
  grep -Fxq 'chromium' "$PINS" && grep -Fxq 'zen' "$PINS" ||
  fail 'dock must seed persistent application pins'
grep -Fq 'background-color: rgba(26, 27, 38, 0.72);' "$STYLE" ||
  fail 'dock background must be translucent'
! jq -e 'any(.[]; .position == "bottom")' "$WAYBAR" >/dev/null ||
  fail 'Waybar must not restore a bottom bar alongside the dock'


tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
config="$tmp/config"
cache="$tmp/cache"
bin="$tmp/bin"
mkdir -p "$config/nwg-dock-hyprland" "$bin"
cp "$PINS" "$config/nwg-dock-hyprland/pinned"
cat >"$bin/nwg-dock-hyprland" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$DOCK_ARGS"
EOF
chmod +x "$bin/nwg-dock-hyprland"
export DOCK_ARGS="$tmp/dock-args"

env XDG_CONFIG_HOME="$config" XDG_CACHE_HOME="$cache" PATH="$bin:$PATH" "$HELPER"
cmp "$PINS" "$cache/nwg-dock-hyprland/nwg-dock-pinned" ||
  fail 'dock must seed its pins when no user pin state exists'
grep -Fxq -- "-x -p bottom -a center -c hypr-app-launcher -s $config/nwg-dock-hyprland/style.css" "$DOCK_ARGS" ||
  fail 'dock must retain its configured geometry and Rofi launcher'
printf 'custom\n' >"$cache/nwg-dock-hyprland/nwg-dock-pinned"
env XDG_CONFIG_HOME="$config" XDG_CACHE_HOME="$cache" PATH="$bin:$PATH" "$HELPER"
[[ "$(<"$cache/nwg-dock-hyprland/nwg-dock-pinned")" == "custom" ]] ||
  fail 'dock must preserve user-managed pins after initialization'
cat >"$bin/pkill" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$PKILL_ARGS"
EOF
chmod +x "$bin/pkill"
export PKILL_ARGS="$tmp/pkill-args"
env XDG_CONFIG_HOME="$config" XDG_CACHE_HOME="$cache" PATH="$bin:$(dirname "$HELPER"):$PATH" "$RELOAD"
[[ "$(<"$PKILL_ARGS")" == "-f nwg-dock-hyprland" ]] ||
  fail 'dock reload must stop the running dock before relaunching it'
printf 'PASS: Hyprland autostarts nwg-dock on the bottom edge\n'
