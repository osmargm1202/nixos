#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

nix eval --impure --raw --expr '
  let
    flake = builtins.getFlake (toString ./.) ;
    profileNames = [ "lenovo-gnome" "lenovo-labwc" "lenovo-hyprland" "lenovo-i3" ];
    configs = builtins.map (name: flake.nixosConfigurations.${name}.config) profileNames;
    hasAutologin = config:
      config.services.displayManager.autoLogin.enable
      && config.services.displayManager.autoLogin.user == "osmarg"
      && builtins.any (line: builtins.match ".*--autologin osmarg.*" line != null)
        config.systemd.services."getty@tty1".serviceConfig.ExecStart;
    hasBootMenu = config:
      config.boot.loader.systemd-boot.configurationLimit == 3
      # systemd-boot renders each specialisation key as NixOS (<key>).
      && builtins.attrNames config.specialisation == [ "battery" "gaming" "server" "windows-vfio" ]
      # A shared key sorts the profiles of the newest generation together.
      && config.specialisation.battery.configuration.boot.loader.systemd-boot.sortKey == "nixos"
      && config.specialisation.gaming.configuration.boot.loader.systemd-boot.sortKey == "nixos"
      && config.specialisation.server.configuration.boot.loader.systemd-boot.sortKey == "nixos"
      && config.specialisation.windows-vfio.configuration.boot.loader.systemd-boot.sortKey == "nixos"
      && config.specialisation.gaming.configuration.orgm.gaming.gamescopeTty1.enable
      && !config.specialisation.gaming.configuration.services.displayManager.sddm.enable
      && builtins.match ".*gamescope -e -- steam -gamepadui.*"
        config.specialisation.gaming.configuration.programs.bash.loginShellInit != null
      && config.specialisation.server.configuration.systemd.defaultUnit == "multi-user.target"
      && config.specialisation.server.configuration.services.openssh.enable
      && config.specialisation.server.configuration.networking.networkmanager.enable
      && !config.specialisation.server.configuration.services.xserver.enable;
  in
    if builtins.all (config: hasAutologin config && hasBootMenu config) configs
    then "Lenovo boot specialisations: ok"
    else throw "Lenovo boot specialisation menu is incomplete"
'
