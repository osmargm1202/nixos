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

assert_host_alias_absent() {
  local expression="$1" alias="$2"
  if nix eval --raw "$expression" | grep -Fq -- "$alias"; then
    fail "$expression unexpectedly contains $alias"
  fi
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
for alias in \
  '100.67.39.12 fifrex.tailb870fa.ts.net fifrex' \
  '100.112.28.88 lenovo.tailb870fa.ts.net lenovo' \
  '100.82.81.79 lenovo-windows.tailb870fa.ts.net lenovo-windows' \
  '100.89.45.64 nextcloud.tailb870fa.ts.net nextcloud' \
  '100.100.134.21 or-gm.tailb870fa.ts.net or-gm' \
  '100.94.177.77 orgm.tailb870fa.ts.net orgm' \
  '100.90.219.91 osmar-iphone-12-pro-max.tailb870fa.ts.net osmar-iphone-12-pro-max' \
  '100.97.77.10 osmar-windows.tailb870fa.ts.net osmar-windows' \
  '100.71.179.123 tony-windows.tailb870fa.ts.net tony-windows'
do
  assert_host_alias '.#nixosConfigurations.lenovo-terminal.config.networking.extraHosts' "$alias"
done
assert_host_alias_absent '.#nixosConfigurations.lenovo-terminal.config.networking.extraHosts' 'orgm-iphone-12-pro-max'
assert_host_alias_absent '.#nixosConfigurations.lenovo-terminal.config.networking.extraHosts' 'orgm-windows'
printf 'PASS: host modules apply consistently across roles\n'
