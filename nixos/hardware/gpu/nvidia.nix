{ config, ... }:

{
  imports = [ ../../hardware/kernel/zen70-pin.nix ];

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
    open = true;
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

  # nvidia-vaapi-driver cannot export dmabufs the way Qt Multimedia requests
  # (vaExportSurfaceHandle fails per frame; upstream limitation, the driver
  # targets Firefox's consumption pattern). NVDEC decode keeps working; this
  # skips the doomed per-frame zero-copy attempt and its fallback churn.
  # Lives in the NVIDIA module on purpose: on Intel/AMD zero-copy works.
  environment.sessionVariables.QT_DISABLE_HW_TEXTURES_CONVERSION = "1";
}
