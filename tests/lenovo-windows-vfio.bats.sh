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
    requiredUdevRule = "SUBSYSTEM==\"vfio\", KERNEL==\"[0-9]*\", GROUP=\"podman\", MODE=\"0660\"";
    isVfio = vfio:
      builtins.all (value: builtins.elem value vfio.boot.kernelParams) requiredParams
      && builtins.all (value: builtins.elem value vfio.boot.initrd.kernelModules) requiredModules
      && vfio.environment.etc."orgm/windows-vm-profile".text == "lenovo-vfio\n"
      && builtins.substring 0 (builtins.stringLength requiredUdevRule) vfio.services.udev.extraRules == requiredUdevRule
      && builtins.any (limit:
        limit.domain == "osmarg"
        && limit.type == "-"
        && limit.item == "memlock"
        && limit.value == "unlimited"
      ) vfio.security.pam.loginLimits
      && builtins.match ".*DefaultLimitMEMLOCK=infinity.*" vfio.systemd.user.extraConfig != null
      && vfio.systemd.services."getty@tty1".serviceConfig.LimitMEMLOCK == "infinity"
      && !vfio.hardware.nvidia.prime.offload.enable;
  in
    if builtins.all isVfio vfioProfiles && standard.hardware.nvidia.prime.offload.enable
    then "lenovo-windows-vfio: ok"
    else throw "lenovo Windows VFIO profile is incomplete"
'
