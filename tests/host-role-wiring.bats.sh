#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_json() {
  local expression="path:$ROOT#${1#.#}" expected="$2"
  [[ "$(nix eval --json "$expression")" == "$expected" ]] || fail "$expression is not $expected"
}
assert_host_alias() {
  local expression="path:$ROOT#${1#.#}" alias="$2"
  nix eval --raw "$expression" | grep -Fxq -- "$alias" ||
    fail "$expression does not contain $alias"
}


assert_json '.#nixosConfigurations.orgm-terminal.config.services.zerotierone.enable' false
assert_json '.#nixosConfigurations.orgm-hyprland.config.services.zerotierone.enable' false
assert_json '.#nixosConfigurations.lenovo-terminal.config.services.zerotierone.enable' false
assert_json '.#nixosConfigurations.jarq-terminal.config.services.zerotierone.enable' false

assert_json '.#nixosConfigurations.lenovo-terminal.config.hardware.graphics.enable' true
assert_json '.#nixosConfigurations.lenovo-hyprland.config.hardware.graphics.enable' true
assert_json '.#nixosConfigurations.lenovo-hyprland.config.boot.loader.systemd-boot.sortKey' '"nixos-01-normal"'
assert_json '.#nixosConfigurations.jarq-terminal.config.hardware.sensor.iio.enable' true
assert_json '.#nixosConfigurations.jarq-hyprland.config.hardware.sensor.iio.enable' true
assert_json '.#nixosConfigurations.ero-terminal.config.hardware.graphics.enable' true
assert_json '.#nixosConfigurations.ero-i3.config.hardware.graphics.enable' true

assert_host_alias '.#nixosConfigurations.lenovo-terminal.config.networking.extraHosts' '172.18.0.251 vilserver1'
assert_host_alias '.#nixosConfigurations.orgm-terminal.config.networking.extraHosts' '172.18.0.251 vilserver1'
assert_host_alias '.#nixosConfigurations.ero-server.config.networking.extraHosts' '172.18.0.251 vilserver1'
assert_json '.#nixosConfigurations.lenovo-terminal.config.services.resolved.enable' true
assert_json '.#nixosConfigurations.ero-server.config.services.resolved.enable' true
assert_json '.#nixosConfigurations.lenovo-terminal.config.services.tailscale.extraSetFlags' '["--accept-dns=false"]'
assert_json '.#nixosConfigurations.lenovo-terminal.config.systemd.services.tailscale-magicdns.wantedBy' '["multi-user.target"]'
assert_json '.#nixosConfigurations.lenovo-terminal.config.systemd.services.tailscale-magicdns.serviceConfig.TimeoutStartSec' '"90s"'
assert_json '.#nixosConfigurations.orgm-hyprland.config.services.earlyoom.freeMemThreshold' 4
assert_json '.#nixosConfigurations.orgm-hyprland.config.systemd.services.earlyoom.environment.EARLYOOM_ARGS' '"-m4,2 -n -r3600 -s100,100 --sort-by-rss"'
assert_json '.#nixosConfigurations.server.config.users.users.osmarg.shell.pname' '"bash-interactive"'
[[ "$(nix eval --json "path:$ROOT#nixosConfigurations.jarq-server.config" \
  --apply 'config: config ? home-manager')" == false ]] ||
  fail 'Jarq server must evaluate without a Home Manager module'
printf 'PASS: host modules apply consistently across roles\n'
