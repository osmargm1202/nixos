{
  config,
  lib,
  userName ? "jarq",
  ...
}:

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
  services.libinput.enable = true;
  hardware.sensor.iio.enable = true;

  home-manager.users.${userName}.dconf.settings."org/gnome/desktop/a11y/applications" = {
    screen-keyboard-enabled = true;
  };

  powerManagement.enable = true;
  powerManagement.powertop.enable = lib.mkDefault true;
}
