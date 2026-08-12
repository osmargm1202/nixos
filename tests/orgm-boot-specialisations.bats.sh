#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

nix eval --impure --raw --expr '
  let
    flake = builtins.getFlake (toString ./.) ;
    profileNames = [ "orgm-cinnamon" "orgm-gnome" "orgm-hyprland" "orgm-i3" "orgm-labwc" ];
    configs = builtins.map (name: flake.nixosConfigurations.${name}.config) profileNames;
    hasServerMode = config:
      let server = config.specialisation.server.configuration;
      in config.boot.loader.systemd-boot.sortKey == "nixos-00-normal"
      && builtins.attrNames config.specialisation == [ "server" ]
      && server.boot.loader.systemd-boot.sortKey == "nixos-01-server"
      && server.systemd.defaultUnit == "multi-user.target"
      && server.services.openssh.enable
      && server.virtualisation.docker.enable
      && !server.services.displayManager.sddm.enable
      && !server.services.displayManager.autoLogin.enable
      && !server.services.xserver.enable
      && !server.services.xserver.desktopManager.cinnamon.enable
      && !server.services.xserver.desktopManager.gnome.enable
      && !server.services.xserver.windowManager.i3.enable
      && !server.services.xserver.displayManager.startx.enable
      && !server.programs.hyprland.enable
      && !server.programs.labwc.enable
      && !server.programs.xwayland.enable;
  in
    if builtins.all hasServerMode configs
    then "ORGM boot specialisations: ok"
    else throw "ORGM boot specialisation menu is incomplete"
'
