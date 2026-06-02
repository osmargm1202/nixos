{ config, lib, ... }:

{
  # Lenovo Flex 3-1570 (80JM): Intel Broadwell + Broadcom BCM4352 WiFi.
  hardware.enableRedistributableFirmware = true;

  boot.extraModulePackages = [ config.boot.kernelPackages.broadcom_sta ];
  boot.blacklistedKernelModules = [
    "b43"
    "bcma"
    "brcmsmac"
    "ssb"
  ];

  services.fwupd.enable = true;
  services.thermald.enable = true;

  powerManagement.enable = true;
  powerManagement.powertop.enable = lib.mkDefault true;
}
