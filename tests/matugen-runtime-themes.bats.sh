#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOTFILES_MODULE="$ROOT/nixos/common-dotfiles.nix"
MANIFEST="$ROOT/dotfiles/config/dotfiles.json"
KITTY_CONF="$ROOT/dotfiles/config/shared/.config/kitty/kitty.conf"
YAZI_CONF="$ROOT/dotfiles/config/shared/.config/yazi/yazi.toml"
KITTY_THEME="$ROOT/dotfiles/config/shared/.config/kitty/skwd-theme.conf"
YAZI_THEME="$ROOT/dotfiles/config/shared/.config/yazi/theme.toml"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[ ! -e "$KITTY_THEME" ] || fail 'Matugen Kitty theme must not exist inside dotfiles'
[ ! -e "$YAZI_THEME" ] || fail 'Matugen Yazi theme must not exist inside dotfiles'

if grep -Fxq '    ".config/kitty"' "$DOTFILES_MODULE"; then
  fail 'Home Manager must not link the whole Kitty runtime directory'
fi
if grep -Fxq '    ".config/yazi"' "$DOTFILES_MODULE"; then
  fail 'Home Manager must not link the whole Yazi runtime directory'
fi

grep -Fq '    ".config/kitty/kitty.conf"' "$DOTFILES_MODULE" ||
  fail 'Home Manager must still deploy tracked Kitty configuration'
grep -Fq '    ".config/yazi/yazi.toml"' "$DOTFILES_MODULE" ||
  fail 'Home Manager must still deploy tracked Yazi configuration'
grep -Fq '    ".config/yazi/flavors"' "$DOTFILES_MODULE" ||
  fail 'Home Manager must still deploy tracked Yazi flavors'

grep -Fq 'include skwd-theme.conf' "$KITTY_CONF" ||
  fail 'Kitty must include the runtime Matugen theme'
grep -Fq 'theme.toml is runtime-owned by Matugen' "$YAZI_CONF" ||
  fail 'Yazi config must document its automatically loaded runtime theme'

jq -e '
  (.shared.paths | index(".config/kitty") | not) and
  (.shared.paths | index(".config/yazi") | not) and
  (.shared.paths | index(".config/kitty/kitty.conf") != null) and
  (.shared.paths | index(".config/yazi/yazi.toml") != null) and
  (.local_only.paths | index(".config/kitty/skwd-theme.conf") != null) and
  (.local_only.paths | index(".config/yazi/theme.toml") != null)
' "$MANIFEST" >/dev/null || fail 'dotfiles manifest must preserve runtime theme ownership boundaries'

printf 'PASS: Kitty and Yazi load runtime-owned Matugen themes\n'
