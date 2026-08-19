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

grep -Fq 'nwgDockHyprland = pkgs.nwg-dock-hyprland.overrideAttrs' "$PROFILE" &&
  grep -Fq 'version = "0.4.11";' "$PROFILE" &&
  grep -Fq 'tag = "v0.4.11";' "$PROFILE" &&
  grep -Eq '^[[:space:]]+nwgDockHyprland[[:space:]]*$' "$PROFILE" ||
  fail 'Hyprland must install nwg-dock-hyprland 0.4.11 with Hyprland 0.55 focus support'
grep -Fq '"sh -lc '\''exec \"$HOME/.local/bin/hypr-nwg-dock\"'\''",' "$AUTOSTART" ||
  fail 'Hyprland must launch the dock through an absolute helper path'
grep -Fq 'dock_bin="${NWG_DOCK_BIN:-nwg-dock-hyprland}"' "$HELPER" &&
  grep -Fq 'exec "$dock_bin" \' "$HELPER" ||
  fail 'Hyprland must reserve bottom space for the persistent dock'
grep -Fq 'PATH="$HOME/.local/bin:/run/current-system/sw/bin:' "$HELPER" ||
  fail 'dock helper must retain the NixOS system command path'
grep -Fq -- '-c hypr-app-launcher' "$HELPER" ||
  fail 'dock launcher button must open the Rofi app launcher'
grep -Fxq 'kitty' "$PINS" && grep -Fxq 'thunar' "$PINS" &&
  grep -Fxq 'firefox' "$PINS" && ! grep -Fxq 'zen' "$PINS" ||
  fail 'dock must seed Firefox without a Zen pin'
grep -Fq '@import url("orgm-current.css");' "$STYLE" ||
  fail 'dock style must import the generated translucent palette'
! jq -e 'any(.[]; .position == "bottom")' "$WAYBAR" >/dev/null ||
  fail 'Waybar must not restore a bottom bar alongside the dock'


tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
home="$tmp/home"
state="$tmp/state"
config="$tmp/config"
cache="$tmp/cache"
bin="$tmp/bin"
mkdir -p "$home" "$state" "$config/nwg-dock-hyprland" "$bin"
cp "$PINS" "$config/nwg-dock-hyprland/pinned"
cat >"$bin/nwg-dock-hyprland" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$DOCK_ARGS"
EOF
chmod +x "$bin/nwg-dock-hyprland"
export DOCK_ARGS="$tmp/dock-args"

env HOME="$home" XDG_STATE_HOME="$state" XDG_CONFIG_HOME="$config" XDG_CACHE_HOME="$cache" NWG_DOCK_BIN="$bin/nwg-dock-hyprland" PATH="$bin:$PATH" "$HELPER"
cmp "$PINS" "$cache/nwg-dock-pinned" ||
  fail 'dock must seed its pins when no user pin state exists'
[[ ! -e "$cache/nwg-dock-hyprland/nwg-dock-pinned" ]] ||
  fail 'dock must not initialize pins in the legacy nested cache path'
grep -Fxq -- "-x -p bottom -a center -mb 14 -c hypr-app-launcher -s style.css" "$DOCK_ARGS" ||
  fail 'dock must retain its floating bottom geometry and Rofi launcher'
printf 'custom\n' >"$cache/nwg-dock-pinned"
env HOME="$home" XDG_STATE_HOME="$state" XDG_CONFIG_HOME="$config" XDG_CACHE_HOME="$cache" NWG_DOCK_BIN="$bin/nwg-dock-hyprland" PATH="$bin:$PATH" "$HELPER"
[[ "$(<"$cache/nwg-dock-pinned")" == "custom" ]] ||
  fail 'dock must preserve user-managed pins after initialization'
cat >"$bin/pkill" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$PKILL_ARGS"
EOF
chmod +x "$bin/pkill"
export PKILL_ARGS="$tmp/pkill-args"
env HOME="$home" XDG_STATE_HOME="$state" XDG_CONFIG_HOME="$config" XDG_CACHE_HOME="$cache" NWG_DOCK_BIN="$bin/nwg-dock-hyprland" PATH="$bin:$(dirname "$HELPER"):$PATH" "$RELOAD"
[[ "$(<"$PKILL_ARGS")" == "-f nwg-dock-hyprland" ]] ||
  fail 'dock reload must stop the running dock before relaunching it'
printf 'PASS: Hyprland autostarts a floating nwg-dock\n'
