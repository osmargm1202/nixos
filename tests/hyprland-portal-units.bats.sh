#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

nix eval --impure --raw --expr '
  let
    flake = builtins.getFlake (toString ./.) ;
    profileNames = [ "jarq-hyprland" "orgm-hyprland" "lenovo-hyprland" ];
    configs = builtins.map (name: flake.nixosConfigurations.${name}.config) profileNames;
    hasOneHyprlandPortal = config:
      builtins.length (builtins.filter (
        portal: portal == config.programs.hyprland.portalPackage
      ) config.xdg.portal.extraPortals) == 1;
  in
    if builtins.all hasOneHyprlandPortal configs
    then "Hyprland portal unit provider: ok"
    else throw "Hyprland portal unit is declared more than once"
'
