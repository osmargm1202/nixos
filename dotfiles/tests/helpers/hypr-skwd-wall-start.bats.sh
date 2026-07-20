#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/config/profiles/hyprland/.local/bin/hypr-skwd-wall-start"
AUTOSTART="$ROOT/config/profiles/hyprland/.config/hypr/lua/autostart.lua"
DOTFILES_MODULE="$(cd "$ROOT/.." && pwd)/nixos/common-dotfiles.nix"
PROFILE="$(cd "$ROOT/.." && pwd)/nixos/profiles/hyprland.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[ ! -e "$SCRIPT" ] && [ ! -L "$SCRIPT" ] || fail "obsolete hypr-skwd-wall-start must be removed"
if grep -Fq 'hypr-skwd-wall-start' "$AUTOSTART"; then
  fail "autostart must not invoke the obsolete Skwd bootstrap"
fi
if grep -Fq '.local/bin/hypr-skwd-wall-start' "$DOTFILES_MODULE"; then
  fail "dotfiles module must not deploy the obsolete Skwd bootstrap"
fi
grep -Fq 'systemd.user.targets.graphical-session.wants = [ "skwd-daemon.service" ];' "$PROFILE" ||
  fail "graphical session must start skwd-daemon declaratively"
grep -Fq '"sh -lc '\''hypr-session-import-env && systemctl --user start graphical-session.target'\''",' "$AUTOSTART" ||
  fail "Hyprland must import its environment before activating graphical-session.target"
if grep -Fq 'systemctl --user start skwd-daemon.service' "$AUTOSTART"; then
  fail "Hyprland must activate the graphical target instead of starting Skwd directly"
fi

printf 'PASS: Hyprland activates the graphical target for declarative Skwd startup\n'
