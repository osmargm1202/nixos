{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.orgm.jarq.wifi.experimental.enable =
    lib.mkEnableOption "BCM4352 proprietary wl driver with accepted security risk and software DMA";

  config = lib.mkMerge [
    {
      # b43 cannot drive BCM4352. An explicit disable also quarantines wl.
      boot.blacklistedKernelModules = [
        "b43"
        "bcma"
        "ssb"
      ];
    }
    (lib.mkIf (!config.orgm.jarq.wifi.experimental.enable) {
      boot.blacklistedKernelModules = [ "wl" ];
    })
    (lib.mkIf config.orgm.jarq.wifi.experimental.enable {
      # wl can reject MAC changes and subsequent scans (BCME error 23).
      # Keep the hardware address and disable power saving on this appliance.
      networking.networkmanager.wifi.scanRandMacAddress = false;
      networking.networkmanager.settings."connection-jarq-wifi" = {
        "match-device" = "interface-name:wlp2s0";
        "wifi.cloned-mac-address" = "permanent";
        "wifi.powersave" = 2;
      };
      assertions = [
        {
          assertion =
            builtins.elem "iommu=soft" config.boot.kernelParams
            && !(builtins.elem "iommu=off" config.boot.kernelParams);
          message = "Jarq wl requires software DMA bounce buffers (iommu=soft, never iommu=off).";
        }
      ];

      # BCM4352 PCI 14e4:43b1 has no b43 support (UNSUPPORTED PHY / probe -95).
      # Keep the driver's kernel/patches from the selected kernel package set, but
      # use the host stdenv so this host's security policy is honored: the Zen pin
      # imports a separate nixpkgs instance without the host's insecure allowance.
      # Retain the kernel's compiler (GCC 14), not the host's newer GCC 15.
      boot.extraModulePackages = [
        (config.boot.kernelPackages.broadcom_sta.override {
          stdenv = pkgs.overrideCC pkgs.stdenv config.boot.kernelPackages.kernel.stdenv.cc;
        })
      ];
      boot.kernelModules = [ "wl" ];

      # Explicitly accepted for Jarq only: unmaintained proprietary driver with
      # CVE-2019-9501/CVE-2019-9502. Fail closed on driver/kernel version changes;
      # prefer replacing the Wi-Fi hardware over broadening this exception.
      nixpkgs.config.permittedInsecurePackages = [ "broadcom-sta-6.30.223.271-59-7.0.10" ];
    })
  ];
}
