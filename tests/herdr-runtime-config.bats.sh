#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}


home_files="$(nix eval --json \
  "path:$ROOT#nixosConfigurations.orgm-hyprland.config.home-manager.users.osmarg.home.file")"
jq -e 'keys | all(. != ".config/herdr" and (startswith(".config/herdr/") | not))' <<<"$home_files" >/dev/null ||
  fail 'Home Manager must not link or own the Herdr runtime directory'

printf 'PASS: Herdr configuration and state are exclusively runtime-owned\n'
