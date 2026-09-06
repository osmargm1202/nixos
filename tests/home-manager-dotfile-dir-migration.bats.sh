#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/nixos/scripts/migrate-home-manager-dotfile-dirs.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	exit 1
}

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

# The live failure: an externally installed skill uses a relative directory
# link. Migration must detach it without modifying the external skill.
skill=".pi/agent/skills/find-skills"
external="$HOME/.agents/skills/find-skills"
mkdir -p "$HOME/.pi/agent/skills" "$external" "$HOME/.agents/skills/shared"
printf 'original skill\n' >"$external/SKILL.md"
printf 'user notes\n' >"$external/local-notes.txt"
printf 'shared reference\n' >"$HOME/.agents/skills/shared/reference.txt"
ln -s ../shared "$external/references"
ln -s ../../../.agents/skills/find-skills "$HOME/$skill"
"$SCRIPT" "$skill" "$skill/references"
[ -d "$HOME/$skill" ] && [ ! -L "$HOME/$skill" ] ||
	fail 'external skill must become an independent directory'
[ ! -L "$HOME/$skill/references" ] ||
	fail 'nested links must not lead cleanup back to external files'

# Simulate managed-leaf replacement after migration.
rm "$HOME/$skill/SKILL.md" "$HOME/$skill/references/reference.txt"
printf 'declarative skill\n' >"$HOME/$skill/SKILL.md"
[ "$(cat "$external/SKILL.md")" = 'original skill' ] ||
	fail 'managed-leaf replacement must preserve the original skill'
[ "$(cat "$HOME/.agents/skills/shared/reference.txt")" = 'shared reference' ] ||
	fail 'nested external targets must remain intact'
[ "$(cat "$HOME/$skill/local-notes.txt")" = 'user notes' ] ||
	fail 'unmanaged local files must survive migration'
backups=("$HOME/$skill".hm-migration.*.original-link)
[ "${#backups[@]}" -eq 1 ] && [ -L "${backups[0]}" ] ||
	fail 'migration must preserve the original directory link'
[ "$(cat "${backups[0]}/SKILL.md")" = 'original skill' ] ||
	fail 'the preserved relative link must still resolve to its original target'
"$SCRIPT" "$skill"
[ "$(cat "$HOME/$skill/SKILL.md")" = 'declarative skill' ] ||
	fail 'repeated migration must not restore old managed content'

# A copy failure must leave the original link in place.
mkdir -p "$TMP/incomplete"
ln -s "$TMP/missing-file" "$TMP/incomplete/broken"
ln -s "$TMP/incomplete" "$HOME/.config/incomplete"
if "$SCRIPT" .config/incomplete 2>"$TMP/error"; then
	fail 'an incomplete copy must abort migration'
fi
[ -L "$HOME/.config/incomplete" ] && [ -L "$TMP/incomplete/broken" ] ||
	fail 'a failed copy must preserve both the original link and its source'

printf 'PASS: legacy Home Manager directory links migrate safely\n'
