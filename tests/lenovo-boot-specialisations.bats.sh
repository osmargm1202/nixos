#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

nix eval --impure --raw --expr '
  let
    flake = builtins.getFlake (toString ./.) ;
    profileNames = [ "lenovo-labwc" "lenovo-hyprland" "lenovo-i3" ];
    configs = builtins.map (name: flake.nixosConfigurations.${name}.config) profileNames;
    hasBootMenu = config:
      config.boot.loader.timeout == 10
      && config.specialisation.battery.configuration.boot.loader.systemd-boot.sortKey == "nixos-battery"
      && config.specialisation.gaming.configuration.boot.loader.systemd-boot.sortKey == "nixos-gaming"
      && config.specialisation.windows-vfio.configuration.boot.loader.systemd-boot.sortKey == "nixos-windows-vfio";
  in
    if builtins.all hasBootMenu configs
    then "Lenovo boot specialisations: ok"
    else throw "Lenovo boot specialisation menu is incomplete"
'
