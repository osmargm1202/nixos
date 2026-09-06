#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KITTY_CONF="$ROOT/dotfiles/config/shared/.config/kitty/kitty.conf"
KITTY_THEME="$ROOT/dotfiles/config/shared/.config/kitty/skwd-theme.conf"
YAZI_CONFIG="$ROOT/dotfiles/config/shared/.config/yazi"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[ ! -e "$KITTY_THEME" ] || fail 'Matugen Kitty theme must not exist inside dotfiles'
[ ! -e "$YAZI_CONFIG" ] || fail 'Obsolete Yazi configuration must not exist inside dotfiles'
grep -Fq 'include current-theme.conf' "$KITTY_CONF" ||
  fail 'Kitty must include the runtime Matugen theme'

home_files="$(nix eval --json \
  "path:$ROOT#nixosConfigurations.orgm-hyprland.config.home-manager.users.osmarg.home.file")"
jq -e '
  has(".config/kitty/kitty.conf") and
  (has(".config/kitty/current-theme.conf") | not) and
  (has(".config/yazi/yazi.toml") | not) and
  (has(".config/yazi/keymap.toml") | not) and
  (has(".config/yazi/package.toml") | not) and
  (has(".config/yazi/flavors") | not)
' <<<"$home_files" >/dev/null ||
  fail 'Home Manager must deploy tracked Kitty config without owning runtime theme or obsolete Yazi files'

printf 'PASS: Kitty loads its runtime Matugen theme without owning generated config\n'
