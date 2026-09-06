#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"
MODULE="$ROOT/nixos/udiskie.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

! grep -Eq '^[[:space:]]*exec.*udiskie' "$CONFIG" ||
  fail 'i3 must not launch a second udiskie outside systemd'
grep -Fq 'systemd.user.services.udiskie' "$MODULE" ||
  fail 'udiskie must be owned by one systemd user service'
command="$(nix eval --raw "path:$ROOT#nixosConfigurations.lenovo-i3.config.systemd.user.services.udiskie.serviceConfig.ExecStart")"
[[ "$command" == *'/bin/udiskie --automount --notify --tray' ]] ||
  fail 'the managed udiskie service must retain automount and tray support'

printf 'PASS: i3 uses exactly one managed udiskie service\n'
