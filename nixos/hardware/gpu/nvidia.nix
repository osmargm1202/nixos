{ config, pkgs, inputs, ... }:

{
  services.xserver.videoDrivers = [ "nvidia" ];

  # Driver 580.142 (open and proprietary source trees both) unconditionally
  # includes linux/of_gpio.h, which linux-zen 7.1.2 (common.nix's default
  # kernel, from the current nixpkgs pin) no longer ships. Pull zen from the
  # nixpkgs-zen70 input instead -- same zen flavour, still has the header.
  boot.kernelPackages =
    (import inputs.nixpkgs-zen70 {
      system = pkgs.stdenv.hostPlatform.system;
      config.allowUnfree = true;
    }).linuxPackages_zen;

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
}
