{ config, ... }:

{
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  hardware.nvidia-container-toolkit.enable = true;

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  boot.kernelParams = [ "nvidia.NVreg_PreserveVideoMemoryAllocations=1" ];

  boot.extraModprobeConfig = ''
    options nvidia NVreg_PreserveVideoMemoryAllocations=1
  '';

  boot.kernelModules = [
    "nvidia"
    "nvidia_drm"
    "nvidia_modeset"
  ];
}
