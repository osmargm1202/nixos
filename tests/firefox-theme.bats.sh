#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
module="$repo_dir/nixos/firefox.nix"
theme="$repo_dir/nixos/packages/firefox-themes/grunge-impact-1.0.xpi"
theme_id="{59129a6b-d6a6-452b-a5a6-df49f45ad943}"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

unzip -t "$theme" >/dev/null || fail 'theme XPI is invalid'
actual_id="$(unzip -p "$theme" manifest.json | python3 -c 'import json, sys; print(json.load(sys.stdin)["browser_specific_settings"]["gecko"]["id"])')"
[[ "$actual_id" == "$theme_id" ]] || fail 'theme XPI ID differs from the managed policy ID'
grep -Fq 'grunge-impact-1.0.xpi' "$module" || fail 'Firefox must retain the theme XPI'
grep -Fq 'installation_mode = "force_installed";' "$module" || fail 'Firefox must force-install the theme'

printf 'PASS: Firefox force-installs the signed Grunge Impact theme\n'
