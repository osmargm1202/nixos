#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASH_CONFIG="$ROOT/dotfiles/config/shared/.config/bash/config.bash"
HYPR_ENV="$ROOT/dotfiles/config/profiles/hyprland/.config/hypr/lua/environment.lua"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

# Hyprland re-evaluates its Lua config on every reload and feeds the result to
# every process it spawns, so a blind prepend grows PATH without bound.
! grep -Fq 'path = "/run/wrappers/bin:" .. home .. "/.local/bin:" .. path' "$HYPR_ENV" ||
  fail 'Hyprland env prepends PATH without dropping entries it already exported'
grep -Fq 'seen[dir]' "$HYPR_ENV" ||
  fail 'Hyprland env does not deduplicate PATH entries'

# Nested interactive shells re-run config.bash over an inherited PATH.
grep -Fq '_orgm_path_with' "$BASH_CONFIG" ||
  fail 'Bash config does not build PATH through the deduplicating helper'
! grep -Eq '^export PATH="/run/wrappers/bin:\$HOME/\.local/bin:.*:\$PATH"$' "$BASH_CONFIG" ||
  fail 'Bash config still prepends PATH unconditionally'
bash -n "$BASH_CONFIG"

dirty="/run/wrappers/bin:$HOME/.local/bin:/run/wrappers/bin:$HOME/.local/bin:/usr/bin"
helper="$(sed -n '/^_orgm_path_with() {$/,/^}$/p' "$BASH_CONFIG")"
[[ -n "$helper" ]] || fail 'could not extract the PATH helper from the Bash config'
deduped="$(
  PATH="$dirty" "$BASH" --norc -c "$helper"'
    printf "%s" "$(_orgm_path_with /run/wrappers/bin "$HOME/.local/bin")"
  '
)"
[[ "$deduped" == "/run/wrappers/bin:$HOME/.local/bin:/usr/bin" ]] ||
  fail "PATH helper did not collapse repeats: $deduped"

printf 'PASS: session PATH stays free of repeated entries\n'
