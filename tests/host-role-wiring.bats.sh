#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_json() {
  local expression="$1" expected="$2"
  [[ "$(nix eval --json "$expression")" == "$expected" ]] || fail "$expression is not $expected"
}
assert_host_alias() {
  local expression="$1" alias="$2"
  nix eval --raw "$expression" | grep -Fxq -- "$alias" ||
    fail "$expression does not contain $alias"
}

assert_json '.#nixosConfigurations.orgm-terminal.config.services.zerotierone.enable' true
assert_json '.#nixosConfigurations.orgm-hyprland.config.services.zerotierone.enable' true
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
printf 'PASS: host modules apply consistently across roles\n'
