#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE="$ROOT/dotfiles/config/shared/.config/bash/sops-age.bash"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[[ -f $MODULE ]] || fail 'SOPS Age shell module is missing'

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
home="$tmp/home"
config="$home/.config"
default_key="$home/Nextcloud/Documentos/keys/age.txt"
custom_key="$tmp/custom-age.txt"
explicit_key="$tmp/explicit-age.txt"
mkdir -p "$(dirname "$default_key")" "$config"
printf '%s\n' 'AGE-SECRET-KEY-default' > "$default_key"
printf '%s\n' 'AGE-SECRET-KEY-custom' > "$custom_key"
printf '%s\n' 'AGE-SECRET-KEY-explicit' > "$explicit_key"

HOME="$home" XDG_CONFIG_HOME="$config" bash -c '
  source "$1"
  [[ $SOPS_AGE_KEY_FILE == "$HOME/Nextcloud/Documentos/keys/age.txt" ]]
  sops-age-key "$2"
  [[ $SOPS_AGE_KEY_FILE == "$XDG_CONFIG_HOME/sops/age/keys.txt" ]]
  [[ $(readlink "$SOPS_AGE_KEY_FILE") == "$2" ]]
  [[ $(stat -c %a "$(dirname "$SOPS_AGE_KEY_FILE")") == 700 ]]
' bash "$MODULE" "$custom_key"

HOME="$home" XDG_CONFIG_HOME="$config" bash -c '
  source "$1"
  [[ $SOPS_AGE_KEY_FILE == "$XDG_CONFIG_HOME/sops/age/keys.txt" ]]
  [[ $(readlink "$SOPS_AGE_KEY_FILE") == "$2" ]]
' bash "$MODULE" "$custom_key"

rm -f "$custom_key"
HOME="$home" XDG_CONFIG_HOME="$config" bash -c '
  source "$1"
  [[ $SOPS_AGE_KEY_FILE == "$HOME/Nextcloud/Documentos/keys/age.txt" ]]
' bash "$MODULE"

HOME="$home" XDG_CONFIG_HOME="$config" SOPS_AGE_KEY_FILE="$explicit_key" bash -c '
  source "$1"
  [[ $SOPS_AGE_KEY_FILE == "$2" ]]
' bash "$MODULE" "$explicit_key"

HOME="$home" XDG_CONFIG_HOME="$config" bash -c '
  source "$1"
  sops-age-key --reset
  [[ $SOPS_AGE_KEY_FILE == "$XDG_CONFIG_HOME/sops/age/keys.txt" ]]
  [[ $(readlink "$SOPS_AGE_KEY_FILE") == "$HOME/Nextcloud/Documentos/keys/age.txt" ]]
' bash "$MODULE"

printf '%s\n' 'sops-age-key: ok'
