# Hardware inventory generated on envy; filesystems follow its guarded installer.
{ config, lib, modulesPath, ... }:
let
  btrfs = subvol: {
    device = "/dev/disk/by-label/ENVY_ROOT";
    fsType = "btrfs";
    options = [ "subvol=${subvol}" "compress=zstd:3" "noatime" ];
  };
in
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];
  boot.initrd.availableKernelModules = [
    "xhci_pci" "ahci" "nvme" "usb_storage" "usbhid"
    "sd_mod" "sr_mod" "sdhci_pci"
  ];
  boot.kernelModules = [ "kvm-intel" ];
  fileSystems = {
    "/" = btrfs "@root";
    "/home" = btrfs "@home";
    "/nix" = (btrfs "@nix") // { neededForBoot = true; };
    "/var/log" = btrfs "@log";
    # Reserved storage only. No Windows guest or service is installed yet.
    "/var/lib/windows" = btrfs "@windows";
    "/boot" = {
      device = "/dev/disk/by-label/ENVY_EFI";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };
  };
  swapDevices = [ ];
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
