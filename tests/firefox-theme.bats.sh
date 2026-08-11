#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
settings="$(cd "$repo_dir" && nix eval --impure --json '.#nixosConfigurations.lenovo-i3.config.programs.firefox.policies.ExtensionSettings')"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_amo_addon() {
  local id="$1"
  local expected_url="https://addons.mozilla.org/firefox/downloads/latest/${id}/latest.xpi"

  jq -e --arg id "$id" --arg url "$expected_url" '
    .[$id].installation_mode == "force_installed"
    and .[$id].install_url == $url
  ' <<<"$settings" >/dev/null ||
    fail "$id must be force-installed from AMO"
}

assert_amo_addon "{22b0eca1-8c02-4c0d-a5d7-6604ddd9836e}"
assert_amo_addon "jid1-NIfFY2CA8fy1tg@jetpack"
assert_amo_addon "{446900e4-71c2-419f-a6a7-df9c091e268b}"

printf 'PASS: Firefox installs the requested AMO theme and extensions\n'
