#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

nix eval --impure --raw --expr '
  let
    flake = builtins.getFlake (toString ./.) ;
    vfioProfileNames = [
      "lenovo-windows-labwc"
      "lenovo-windows-gnome"
      "lenovo-windows-hyprland"
      "lenovo-windows-i3"
      "lenovo-windows-cinnamon"
    ];
    vfioProfiles = builtins.map (name: flake.nixosConfigurations.${name}.config) vfioProfileNames;
    standard = flake.nixosConfigurations.lenovo-hyprland.config;
    requiredParams = [ "intel_iommu=on" "iommu=pt" "vfio-pci.ids=10de:1fbb" ];
    requiredModules = [ "vfio" "vfio_pci" "vfio_iommu_type1" ];
    isVfio = vfio:
      builtins.all (value: builtins.elem value vfio.boot.kernelParams) requiredParams
      && builtins.all (value: builtins.elem value vfio.boot.initrd.kernelModules) requiredModules
      && vfio.environment.etc."orgm/windows-vm-profile".text == "lenovo-vfio\n"
      && !vfio.hardware.nvidia.prime.offload.enable;
  in
    if builtins.all isVfio vfioProfiles && standard.hardware.nvidia.prime.offload.enable
    then "lenovo-windows-vfio: ok"
    else throw "lenovo Windows VFIO profile is incomplete"
'
