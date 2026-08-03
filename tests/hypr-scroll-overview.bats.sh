#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT/nixos/profiles/hyprland.nix"
PACKAGE="$ROOT/nixos/packages/hyprland-scroll-overview.nix"
AUTOSTART="$ROOT/dotfiles/config/profiles/hyprland/.config/hypr/lua/autostart.lua"
BINDINGS="$ROOT/dotfiles/config/profiles/hyprland/.config/hypr/lua/keybindings.lua"
LOOK_AND_FEEL="$ROOT/dotfiles/config/profiles/hyprland/.config/hypr/lua/look-and-feel.lua"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

for file in "$PROFILE" "$PACKAGE" "$AUTOSTART" "$BINDINGS" "$LOOK_AND_FEEL"; do
  [[ -f $file ]] || fail "missing $file"
done

grep -Fq 'repo = "hyprland-scroll-overview";' "$PACKAGE"
grep -Fq 'version = "2efa6168e072194005152106ded1d7acd3a5170c";' "$PACKAGE"
grep -Fq 'hash = "sha256-l+47qR3CWO/3xdTLuC23Nktmys7ibRjhVU4gW19NtYg=";' "$PACKAGE"
grep -Fq 'environment.etc."scrolloverview.so".source = scrollOverviewLibrary;' "$PROFILE"
grep -Fq '"hyprctl plugin load /etc/scrolloverview.so",' "$AUTOSTART"
grep -Fq 'hl.on("hyprland.start", function()' "$AUTOSTART"
grep -Fq 'hl.bind("ALT + Tab", hl.dsp.exec_cmd("hyprctl dispatch scrolloverview:overview toggle"))' "$BINDINGS"
grep -Fq 'if hl.plugin and hl.plugin.scrolloverview then' "$LOOK_AND_FEEL"
grep -Fq 'hl.plugin.scrolloverview.configure({' "$LOOK_AND_FEEL"
grep -Fq 'layout = "vertical",' "$LOOK_AND_FEEL"
grep -Fq 'workspace_gap = 24,' "$LOOK_AND_FEEL"

printf '%s\n' 'hypr-scroll-overview: ok'
