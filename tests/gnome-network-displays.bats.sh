#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

installed="$(nix eval --quiet --raw --impure --expr '
  let
    flake = builtins.getFlake (toString ./.) ;
    packages = flake.nixosConfigurations.lenovo-hyprland.config.environment.systemPackages;
    firewallPorts = flake.nixosConfigurations.lenovo-hyprland.config.networking.firewall.allowedTCPPorts;
  in
    if
      builtins.any (package: (package.pname or "") == "gnome-network-displays") packages
      && builtins.elem 7236 firewallPorts
    then "true"
    else "false"
')"
[[ "$installed" == "true" ]]

printf '%s\n' 'gnome-network-displays: ok'
