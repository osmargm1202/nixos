#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

for profile in lenovo-gnome lenovo-labwc lenovo-hyprland lenovo-i3 lenovo-ryoku lenovo-terminal; do
LENOVO_TEST_CONFIGURATION="$profile" nix eval --impure --raw --expr '
  let
    flake = builtins.getFlake "path:${toString ./.}" ;
    lib = flake.inputs.nixpkgs.lib;
    profileName = builtins.getEnv "LENOVO_TEST_CONFIGURATION";
    config = (import ./tests/fixtures/legacy-configurations.nix).${profileName}.config;
    vfioProfiles = if profileName == "lenovo-terminal" then [ ] else [
      config.specialisation.windows-vfio.configuration
      config.specialisation.server.configuration
    ];
    configs = [ config ] ++ builtins.map (s: s.configuration) (builtins.attrValues config.specialisation);
    requiredParams = [ "intel_iommu=on" "iommu=pt" "vfio-pci.ids=10de:1fbb" ];
    requiredModules = [ "vfio" "vfio_pci" "vfio_iommu_type1" ];
    requiredUdevRule = "SUBSYSTEM==\"vfio\", KERNEL==\"[0-9]*\", GROUP=\"podman\", MODE=\"0660\"";
    requiredKvmfrUdevRule = "KERNEL==\"kvmfr0\", GROUP=\"podman\", MODE=\"0660\"";
    requiredKvmfrModprobe = "options kvmfr static_size_mb=128";
    requiredLookingGlassClient = "looking-glass-client-B7-544-d3fff4eb";
    hasLookingGlass = vfio:
      builtins.elem "kvmfr" vfio.boot.kernelModules
      && lib.hasInfix requiredKvmfrModprobe vfio.boot.extraModprobeConfig
      && builtins.any (pkg: builtins.match "kvmfr-.*" pkg.name != null) vfio.boot.extraModulePackages
      && builtins.any (pkg: pkg.name == requiredLookingGlassClient) vfio.environment.systemPackages
      && lib.hasInfix requiredKvmfrUdevRule vfio.services.udev.extraRules;
    isVfio = vfio:
      builtins.all (value: builtins.elem value vfio.boot.kernelParams) requiredParams
      && builtins.all (value: builtins.elem value vfio.boot.initrd.kernelModules) requiredModules
      && vfio.environment.etc."orgm/windows-vm-profile".text == "lenovo-vfio\n"
      && lib.hasInfix requiredUdevRule vfio.services.udev.extraRules
      && builtins.any (limit:
        limit.domain == "osmarg"
        && limit.type == "-"
        && limit.item == "memlock"
        && limit.value == "unlimited"
      ) vfio.security.pam.loginLimits
      && builtins.match ".*DefaultLimitMEMLOCK=infinity.*" vfio.systemd.user.extraConfig != null
      && !vfio.hardware.nvidia.prime.offload.enable;
    hasBootWindows = c:
      builtins.elem "video=eDP-1:d" c.boot.kernelParams
      && c.virtualisation.podman.enable
      && c.users.users.osmarg.linger
      && builtins.elem "podman" c.users.users.osmarg.extraGroups
      && c.systemd.user.services.lenovo-windows-autostart.wantedBy == [ "default.target" ]
      && !(c.systemd.user.services.lenovo-windows-autostart.serviceConfig ? ExecStop)
      && !c.systemd.user.services.lenovo-windows-autostart.restartIfChanged
      && builtins.all (a: a.assertion) c.assertions;
  in
    if builtins.all isVfio vfioProfiles
      && builtins.all hasLookingGlass vfioProfiles
      && builtins.all hasBootWindows configs
      && !config.orgm.lenovo.windowsVfio.enable
      && config.hardware.nvidia.prime.offload.enable
      && config.environment.etc."orgm/windows-vm-profile".text == "lenovo-render-node\n"
      && (profileName == "lenovo-terminal" || (
        !config.specialisation.gaming.configuration.orgm.lenovo.windowsVfio.enable
        && config.specialisation.gaming.configuration.hardware.nvidia.prime.offload.enable
        && !config.specialisation.battery.configuration.orgm.lenovo.windowsVfio.enable
        && config.specialisation.battery.configuration.orgm.lenovo.nvidiaDisabled.enable
      ))
      && !((import ./tests/fixtures/legacy-configurations.nix).orgm-hyprland.config.systemd.user.services ? lenovo-windows-autostart)
    then "${profileName}: server/windows VFIO and Windows autostart ok\n"
    else throw ("${profileName}: Lenovo Windows VFIO or autostart is incomplete " + builtins.toJSON {
      vfio = map isVfio vfioProfiles;
      lookingGlass = map hasLookingGlass vfioProfiles;
      autostart = map hasBootWindows configs;
      normalVfio = config.orgm.lenovo.windowsVfio.enable;
      normalOffload = config.hardware.nvidia.prime.offload.enable;
      normalMarker = config.environment.etc."orgm/windows-vm-profile".text;
    })
'
done
