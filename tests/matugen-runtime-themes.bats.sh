#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOTFILES_MODULE="$ROOT/nixos/common-dotfiles.nix"
MANIFEST="$ROOT/dotfiles/config/dotfiles.json"
KITTY_CONF="$ROOT/dotfiles/config/shared/.config/kitty/kitty.conf"
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
for yazi_path in \
  ".config/yazi/yazi.toml" \
  ".config/yazi/keymap.toml" \
  ".config/yazi/package.toml" \
  ".config/yazi/flavors"; do
  if grep -Fq "    \"$yazi_path\"" "$DOTFILES_MODULE"; then
    fail "Home Manager must not deploy obsolete Yazi configuration: $yazi_path"
  fi
done
grep -Fq 'home.activation.resetYaziConfiguration' "$DOTFILES_MODULE" ||
  fail 'Home Manager must remove managed legacy Yazi configuration'
grep -Fq '.config/yazi/keymap.toml' "$DOTFILES_MODULE" ||
  fail 'Yazi cleanup must remove the legacy keymap link'
grep -Fq '.config/yazi/package.toml' "$DOTFILES_MODULE" ||
  fail 'Yazi cleanup must remove the legacy package link'
grep -Fq '.config/yazi/flavors' "$DOTFILES_MODULE" ||
  fail 'Yazi cleanup must remove the legacy flavors link'
grep -Fq 'include current-theme.conf' "$KITTY_CONF" ||
  fail 'Kitty must include the runtime Matugen theme'

jq -e '
  (.shared.paths | index(".config/kitty") | not) and
  (.shared.paths | index(".config/yazi") | not) and
  (.shared.paths | index(".config/kitty/kitty.conf") != null) and
  (.shared.paths | index(".config/yazi/yazi.toml") | not) and
  (.shared.paths | index(".config/yazi/keymap.toml") | not) and
  (.shared.paths | index(".config/yazi/package.toml") | not) and
  (.shared.paths | index(".config/yazi/flavors") | not) and
  (.local_only.paths | index(".config/kitty/skwd-theme.conf") != null) and
  (.local_only.paths | index(".config/yazi/theme.toml") | not)
' "$MANIFEST" >/dev/null || fail 'dotfiles manifest must preserve runtime theme ownership boundaries'

grep -Fq 'home.activation.setPreferredFileHandlers' "$DOTFILES_MODULE" ||
  fail 'Home Manager must migrate preferred file handlers'
grep -Fq 'if profileName == "hyprland" then "org.gnome.Nautilus.desktop" else "yazi.desktop"' "$DOTFILES_MODULE" ||
  fail 'Hyprland must use Nautilus while other profiles use Yazi'
grep -Fq 'xdg-mime default nvim.desktop "$mime"' "$DOTFILES_MODULE" ||
  fail 'Neovim must be the default text editor'

printf 'PASS: Kitty loads its runtime theme and file handlers branch by profile\n'
