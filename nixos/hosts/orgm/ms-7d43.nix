{ lib, ... }:

{
  imports = [
    ./audio.nix
    ./webapps.nix
  ];

  # MSI MS-7D43 desktop: Intel Alder Lake CPU, NVIDIA primary GPU, NVMe SSD.
  # Keep generated disk/module detection in hardware-configuration.nix; this file
  # carries stable board/model tuning that should survive regenerate-config.
  hardware.enableRedistributableFirmware = true;

  services.fwupd.enable = true;
  services.fstrim.enable = lib.mkDefault true;
  services.smartd.enable = lib.mkDefault true;

  # Load NVIDIA KMS in initrd so Plymouth can render on the primary GPU early.
  boot.initrd.kernelModules = [
    "nvidia"
    "nvidia_modeset"
    "nvidia_uvm"
    "nvidia_drm"
  ];

  boot.kernelParams = lib.mkAfter [ "nvidia-drm.modeset=1" ];
  boot.extraModprobeConfig = lib.mkAfter ''
    options nvidia_drm modeset=1
  '';
}
