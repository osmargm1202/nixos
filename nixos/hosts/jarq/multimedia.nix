# Preserve the boot/Wi-Fi combination already running successfully on Jarq.
# Kept separate from base.nix so the personal desktop's pending work is untouched.
{
  inputs,
  lib,
  pkgs,
  ...
}:
{
  imports = [ ../../apps/bomba.nix ./multimedia-wifi.nix ./home-assistant.nix ];
  orgm.bomba = {
    enable = true;
    proxy = true;
  };
  boot.kernelPackages =
    inputs.nixpkgs-zen70.legacyPackages.${pkgs.stdenv.hostPlatform.system}.linuxPackages_zen;
  # This role replaces the inherited parameters, including Plymouth's splash.
  # Keep the hardware workarounds and explicitly restore the graphical boot.
  boot.kernelParams = lib.mkForce [
    "quiet"
    "splash"
    "loglevel=3"
    "udev.log_level=3"
    "rd.udev.log_level=3"
    "intel_iommu=off"
    "iommu=soft"
    "intremap=off"
    "module_blacklist=i2c_designware_platform,i2c_designware_core"
    "lsm=landlock,yama,bpf"
  ];
  orgm.jarq.wifi.experimental.enable = true;
  orgm.multimedia.exposure = "tailscale";
  orgm.multimedia.tailnetAddress = "100.122.22.48";
  orgm.multimedia.lanAddress = "10.0.0.98";
  orgm.multimedia.tls = true;
  orgm.multimedia.airplayName = "ORGM Jarq";
  orgm.multimedia.airplayNetworks = [ "10.0.0.0/24" ];
  hardware.graphics.extraPackages = lib.mkDefault [ pkgs.intel-media-driver ];
  hardware.graphics.extraPackages32 = lib.mkDefault [ pkgs.pkgsi686Linux.intel-media-driver ];
}
