#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT/nixos/profiles/i3.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

for setting in \
  'HandleLidSwitch = "suspend";' \
  'HandleLidSwitchExternalPower = "suspend";' \
  'HandleLidSwitchDocked = "suspend";' \
  'IdleAction = "ignore";'; do
  grep -Fq "$setting" "$PROFILE" || fail "missing logind setting: $setting"
done

for host in orgm lenovo ero jarq; do
  lid_action="$(nix eval --raw ".#nixosConfigurations.${host}-i3.config.services.logind.settings.Login.HandleLidSwitch" 2>/dev/null)"
  idle_action="$(nix eval --raw ".#nixosConfigurations.${host}-i3.config.services.logind.settings.Login.IdleAction" 2>/dev/null)"
  [[ "$lid_action" == suspend ]] || fail "${host}-i3 does not suspend when its lid closes"
  [[ "$idle_action" == ignore ]] || fail "${host}-i3 may act on idle time"
done

printf 'PASS: i3 suspends only on lid close, not idle time\n'
