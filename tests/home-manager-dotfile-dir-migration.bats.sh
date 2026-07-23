#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/nixos/scripts/migrate-home-manager-dotfile-dirs.sh"
MODULE="$ROOT/nixos/common-dotfiles.nix"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[ -x "$SCRIPT" ] || fail 'migration helper must be executable'

export HOME="$TMP/home"
mkdir -p "$HOME/.config"
ln -s /nix/store/test-home-manager-files/.config/kitty "$HOME/.config/kitty"
ln -s /nix/store/test-home-manager-files/.config/yazi "$HOME/.config/yazi"
"$SCRIPT" .config/kitty .config/yazi
[ -d "$HOME/.config/kitty" ] && [ ! -L "$HOME/.config/kitty" ] ||
  fail 'legacy Kitty link must become a real directory'
[ -d "$HOME/.config/yazi" ] && [ ! -L "$HOME/.config/yazi" ] ||
  fail 'legacy Yazi link must become a real directory'

printf 'keep\n' >"$HOME/.config/kitty/runtime-theme.conf"
"$SCRIPT" .config/kitty
[ "$(cat "$HOME/.config/kitty/runtime-theme.conf")" = keep ] ||
  fail 'real directories and runtime files must be preserved'

ln -s "$TMP/user-managed" "$HOME/.config/unexpected"
if "$SCRIPT" .config/unexpected 2>"$TMP/error"; then
  fail 'unexpected links must be rejected'
fi
[ -L "$HOME/.config/unexpected" ] || fail 'unexpected link must remain untouched'
grep -Fq 'Refusing to remove unexpected symlink' "$TMP/error" ||
  fail 'unexpected link rejection must explain the problem'

grep -Fq 'home.activation.migrateLegacyDotfileDirectories' "$MODULE" ||
  fail 'Home Manager must register the migration activation'
grep -Fq 'lib.hm.dag.entryBefore [ "removeConflictingDotfiles" ]' "$MODULE" ||
  fail 'migration must run before existing link-target cleanup'
grep -Fq '.config/kitty .config/yazi' "$MODULE" ||
  fail 'activation must migrate Kitty and Yazi'

printf 'PASS: legacy Home Manager directory links migrate safely\n'
