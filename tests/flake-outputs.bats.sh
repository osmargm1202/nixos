#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPECTED="$REPO_DIR/tests/fixtures/nixos-configurations.txt"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_eq() {
  local actual="$1" expected="$2" name="$3"
  [[ "$actual" == "$expected" ]] || fail "$name: expected '$expected', got '$actual'"
}

actual_names="$(
  nix eval --json "$REPO_DIR#nixosConfigurations" --apply builtins.attrNames \
    | jq -r '.[]'
)"

diff -u "$EXPECTED" <(printf '%s\n' "$actual_names") \
  || fail 'evaluated nixosConfigurations differ from the public baseline'

if grep -qx 'TEMPLATE' <<<"$actual_names"; then
  fail 'host templates must never be exported as nixosConfigurations'
fi

for mapping in \
  'orgm orgm-hyprland' \
  'lenovo lenovo-hyprland' \
  'jarq jarq-hyprland'
do
  read -r alias target <<<"$mapping"
  alias_drv="$(nix eval --raw "$REPO_DIR#nixosConfigurations.$alias.config.system.build.toplevel.drvPath")"
  target_drv="$(nix eval --raw "$REPO_DIR#nixosConfigurations.$target.config.system.build.toplevel.drvPath")"
  assert_eq "$alias_drv" "$target_drv" "$alias must remain an alias of $target"
done

assert_eq \
  "$(nix eval --raw "$REPO_DIR#nixosConfigurations.ero-server.config.networking.hostName")" \
  'ero' \
  'ero-server hostname'
assert_eq \
  "$(nix eval --raw "$REPO_DIR#nixosConfigurations.jarq-hyprland.config.system.nixos.label")" \
  'hyprland' \
  'jarq-hyprland profile label'
assert_eq \
  "$(nix eval --raw "$REPO_DIR#nixosConfigurations.cinnamon.config.system.nixos.label")" \
  'cinnamon' \
  'generic cinnamon profile label'

printf 'PASS: evaluated flake output baseline\n'
