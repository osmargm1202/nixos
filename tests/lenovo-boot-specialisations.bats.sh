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
      config.boot.loader.systemd-boot.configurationLimit == 3
      # systemd-boot renders each specialisation key as NixOS (<key>).
      && builtins.attrNames config.specialisation == [ "battery" "gaming" "windows-vfio" ]
      # A shared key sorts the profiles of the newest generation together.
      && config.specialisation.battery.configuration.boot.loader.systemd-boot.sortKey == "nixos"
      && config.specialisation.gaming.configuration.boot.loader.systemd-boot.sortKey == "nixos"
      && config.specialisation.windows-vfio.configuration.boot.loader.systemd-boot.sortKey == "nixos";
  in
    if builtins.all hasBootMenu configs
    then "Lenovo boot specialisations: ok"
    else throw "Lenovo boot specialisation menu is incomplete"
'
