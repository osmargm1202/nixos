{
  config,
  lib,
  userName ? "jarq",
  ...
}:

{
  # Lenovo Flex 3-1570 (80JM): Intel Broadwell + Broadcom BCM4352 WiFi.
  hardware.enableRedistributableFirmware = true;

  # BIOS exposes broken VT-d/RMRR reserved-memory regions on this Broadwell laptop.
  # Disable IOMMU/VT-d paths to avoid boot hangs such as:
  # "Firmware Bug: No firmware reserved region can cover this RMRR".
  boot.kernelParams = lib.mkAfter [
    "intel_iommu=off"
    "iommu=off"
    "intremap=off"
  ];

  # Plymouth hangs this laptop during early boot after system initialization.
  boot.plymouth.enable = lib.mkForce false;

  # BCM4352 needs Broadcom STA. Nixpkgs marks it insecure because upstream
  # abandoned it, but this host depends on it unless the WiFi card is replaced.
  nixpkgs.config.allowInsecurePredicate = pkg:
    lib.getName pkg == "broadcom-sta";

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
