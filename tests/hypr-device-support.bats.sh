#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

module='nixos/udiskie.nix'
common='nixos/common.nix'
profile='nixos/profiles/hyprland.nix'
configuration='.#nixosConfigurations.lenovo-hyprland'

[[ -f "$module" ]]
grep -Fq './udiskie.nix' "$common"
! grep -Fq '../udiskie.nix' "$profile"
grep -Fq 'services.udisks2.enable = true;' "$module"
grep -Fq 'services.usbmuxd.enable = true;' "$module"
grep -Fq 'pkgs.ifuse' "$module"
grep -Fq 'pkgs.libimobiledevice' "$module"
grep -Fq -- '--automount --notify --tray' "$module"

[[ "$(nix eval --json "$configuration.config.services.udisks2.enable")" == true ]]
[[ "$(nix eval --json "$configuration.config.services.usbmuxd.enable")" == true ]]
[[ "$(nix eval --json '.#nixosConfigurations.lenovo-i3.config.services.usbmuxd.enable')" == true ]]
udiskie_command="$(nix eval --raw "$configuration.config.systemd.user.services.udiskie.serviceConfig.ExecStart")"
[[ "$udiskie_command" == *'/bin/udiskie --automount --notify --tray' ]]
wanted_by="$(nix eval --json "$configuration.config.systemd.user.services.udiskie.wantedBy")"
jq -e 'index("graphical-session.target") and index("nixos-fake-graphical-session.target")' <<<"$wanted_by" >/dev/null
udiskie_unit="$(nix eval --raw "$configuration.config.systemd.user.units.\"udiskie.service\".text")"
grep -Fq 'After=graphical-session.target' <<<"$udiskie_unit"

gvfs="$(nix eval --raw "$configuration.config.services.gvfs.package")"
[[ -x "$gvfs/libexec/gvfsd-afc" ]]
[[ -x "$gvfs/libexec/gvfsd-mtp" ]]

nix eval --impure --raw --expr '
  let c = (builtins.getFlake (toString ./.)).nixosConfigurations.lenovo-hyprland;
  in if builtins.all (package: builtins.elem package c.config.environment.systemPackages) [
    c.pkgs.udiskie c.pkgs.usbutils c.pkgs.ifuse c.pkgs.libimobiledevice
  ] then "device packages present" else throw "device packages missing"
' >/dev/null

printf '%s\n' 'hypr-device-support: ok'
