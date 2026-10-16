#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
upstream="${RYOKU_SOURCE:-}"
if [[ -z "$upstream" ]]; then
  upstream="$(RYOKU_TEST_REPO="$ROOT" nix eval --impure --raw --expr \
    '(builtins.getFlake ("path:" + builtins.getEnv "RYOKU_TEST_REPO")).inputs.ryoku.outPath')"
fi
hyprland="${RYOKU_HYPRLAND:-}"
if [[ -z "$hyprland" ]]; then
  hyprland="$(RYOKU_TEST_REPO="$ROOT" nix eval --impure --raw --expr \
    '(builtins.getFlake ("path:" + builtins.getEnv "RYOKU_TEST_REPO")).inputs.ryoku.packages.${builtins.currentSystem}.ryoku-hyprland.outPath')/bin/Hyprland"
fi
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/config/orgm-ryoku" "$tmp/state/orgm-ryoku" "$tmp/home" "$tmp/runtime"
chmod 700 "$tmp/runtime"
cp -a "$upstream/ryoku/hyprland/." "$tmp/config/hypr/"
chmod -R u+w "$tmp/config/hypr"
cp "$ROOT"/dotfiles/config/profiles/ryoku/.config/orgm-ryoku/*.lua "$tmp/config/orgm-ryoku/"
cp "$ROOT"/dotfiles/config/users/osmarg/profiles/ryoku/.config/orgm-ryoku/*.lua \
  "$tmp/config/orgm-ryoku/"
cp "$tmp/config/orgm-ryoku/rebind.lua" "$tmp/config/hypr/modules/rebind.lua"
cp "$tmp/config/orgm-ryoku/user.lua" "$tmp/config/hypr/user.lua"
cp "$tmp/config/orgm-ryoku/keyboard.lua" "$tmp/config/hypr/keyboard.lua"
# Render the actual supported store through BOTH pinned native providers.
cp "$ROOT"/dotfiles/config/profiles/ryoku/.config/orgm-ryoku/{desktop-defaults.json,kitty.conf} "$tmp/config/orgm-ryoku/"
cp "$ROOT/nixos/profiles/ryoku/native-session.py" "$tmp/config/orgm-ryoku/"
jq '{required:["tailscale systray --theme light","syncthingtray --single-instance --wait"],optional:["firefox"],desktop:.}' \
  "$ROOT/dotfiles/config/profiles/ryoku/.config/orgm-ryoku/native-keybinds.json" > "$tmp/config/orgm-ryoku/native-session.json"
HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/config" XDG_STATE_HOME="$tmp/state" \
  bash "$ROOT/nixos/profiles/ryoku/prepare.sh"
for backend in hyprland niri; do
  provider="$(RYOKU_TEST_REPO="$ROOT" RYOKU_TEST_BACKEND="$backend" nix eval --impure --raw --expr \
    'let f = builtins.getFlake ("path:" + builtins.getEnv "RYOKU_TEST_REPO"); in f.inputs.ryoku.packages.${builtins.currentSystem}.${"ryoku-wm-" + builtins.getEnv "RYOKU_TEST_BACKEND"}.outPath')"
  env -u HYPRLAND_INSTANCE_SIGNATURE -u WAYLAND_DISPLAY -u DISPLAY \
    HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/config" \
    "$provider/bin/ryoku-wm-$backend" apply "$tmp/config/ryoku/desktop.json" > "$tmp/$backend-report.json"
done
python3 - "$tmp" <<'CHECK'
import json
from pathlib import Path
import sys
root = Path(sys.argv[1])
hypr = (root / "config/hypr/settings.lua").read_text()
niri = (root / "config/niri/settings.kdl").read_text()
binds = (root / "config/niri/rebinds.kdl").read_text()
for command in ("tailscale systray --theme light", "syncthingtray --single-instance --wait", "firefox"):
    assert hypr.count(command) == 1, ("Hypr startup", command)
    assert niri.count(command) == 1, ("Niri startup", command)
assert 'hl.unbind("SUPER + H")' in hypr and 'ryoku-shell stash' in hypr
assert binds.count('ryoku-shell stash') == 1, binds
assert 'Super+H' in binds and 'Super+K' in binds, binds
assert "qs -c keys" in binds, binds
for backend in ("hyprland", "niri"):
    report = json.loads((root / (backend + "-report.json")).read_text())
    assert not any(row["key"].startswith(("desktop.autostart", "desktop.keybinds["))
                   for row in report.get("unhonored", []) or []), report
print("PASS: pinned native providers render shared startup and accessible Stash/help")
CHECK
XDG_CONFIG_HOME="$tmp/config" XDG_STATE_HOME="$tmp/state" \
  "${LUA_BIN:-lua}" "$ROOT/tests/ryoku-shortcuts.lua" "$upstream"
# Existing custom H/K actions must still work after removing placeholders.
# The native help default moves to the first physically available fallback.
jq -n '{desktop:{keybinds:[
  {keys:"SUPER + H",action:"exec",value:"personal-stash"},
  {keys:"SUPER + K",action:"exec",value:"personal-help"},
  {keys:"SUPER + CTRL + ALT + SHIFT + K",action:"exec",value:"personal-other"}
]}}' > "$tmp/config/ryoku/desktop.json"
rm "$tmp/state/orgm-ryoku/native-session-v1.applied.json"
HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/config" XDG_STATE_HOME="$tmp/state" \
  bash "$ROOT/nixos/profiles/ryoku/prepare.sh"
provider="$(RYOKU_TEST_REPO="$ROOT" nix eval --impure --raw --expr \
  '(builtins.getFlake ("path:" + builtins.getEnv "RYOKU_TEST_REPO")).inputs.ryoku.packages.${builtins.currentSystem}.ryoku-wm-hyprland.outPath')"
env -u HYPRLAND_INSTANCE_SIGNATURE -u WAYLAND_DISPLAY -u DISPLAY \
  HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/config" \
  "$provider/bin/ryoku-wm-hyprland" apply "$tmp/config/ryoku/desktop.json" > "$tmp/custom-report.json"
XDG_CONFIG_HOME="$tmp/config" XDG_STATE_HOME="$tmp/state" \
  RYOKU_EXPECT_STASH=personal-stash RYOKU_EXPECT_HELP_CHORD='SUPER + CTRL + ALT + K' \
  "${LUA_BIN:-lua}" "$ROOT/tests/ryoku-shortcuts.lua" "$upstream"
XDG_CONFIG_HOME="$tmp/config" "${LUA_BIN:-lua}" "$ROOT/tests/ryoku-window-rules.lua"
env -u HYPRLAND_INSTANCE_SIGNATURE -u WAYLAND_DISPLAY -u DISPLAY \
  -u GNOME_KEYRING_CONTROL HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/config" \
  XDG_STATE_HOME="$tmp/state" XDG_RUNTIME_DIR="$tmp/runtime" \
  DBUS_SESSION_BUS_ADDRESS="unix:path=$tmp/runtime/no-session-bus" \
  "$hyprland" --verify-config --config "$tmp/config/hypr/hyprland.lua"
