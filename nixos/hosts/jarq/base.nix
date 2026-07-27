{ lib, ... }:

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
    "module_blacklist=i2c_designware_platform,i2c_designware_core"
  ];

  # Disable Plymouth while debugging Jarq boot hangs so kernel/systemd errors stay visible.
  boot.plymouth.enable = lib.mkForce false;

  # BCM4352 is supported by the open-source brcmfmac driver (part of the kernel)
  # with firmware from linux-firmware (enabled via enableRedistributableFirmware above).
  # No extra module packages needed — removed broadcom-sta proprietary driver.
  boot.blacklistedKernelModules = [
    # ACPI INT3432 I2C controller times out and hangs this laptop during boot.
    # Side effect: touchscreen/tablet sensors may stay disabled.
    "i2c_designware_platform"
    "i2c_designware_core"
  ];

  services.fwupd.enable = true;
  services.thermald.enable = true;

  powerManagement.enable = true;
  powerManagement.powertop.enable = lib.mkDefault true;
}
