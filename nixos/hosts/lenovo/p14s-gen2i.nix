{
  config,
  lib,
  pkgs,
  ...
}:

let
  nvidiaPackage = config.hardware.nvidia.package;
  intelMediaRuntime = pkgs.vpl-gpu-rt or pkgs.onevpl-intel-gpu;
in
{
  imports = [
    ./webapps.nix
    # Keep every graphical Lenovo profile on the stable LTS kernel line.
    ../../hardware/kernel/lts.nix
    ../../deskflow.nix
  ];

  # Local equivalent of nixos-hardware's Lenovo ThinkPad P14s Intel Gen 2
  # profile, kept in-repo so Lenovo carries its own host-specific GPU setup.

  # common/pc
  boot.blacklistedKernelModules = lib.optionals (!config.hardware.enableRedistributableFirmware) [
    "ath3k"
  ];

  # common/cpu/intel/cpu-only.nix
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # common/gpu/intel + common/gpu/intel/tiger-lake
  boot.initrd.kernelModules = [ "i915" ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = [
      pkgs.intel-media-driver
      pkgs.intel-compute-runtime
      intelMediaRuntime
    ];
    extraPackages32 = [ pkgs.driversi686Linux.intel-media-driver ];
  };

  # common/gpu/nvidia/prime.nix + common/gpu/nvidia/turing
  services.xserver.videoDrivers = [ "nvidia" ];

  environment.systemPackages = [ nvidiaPackage ];

  hardware.nvidia = {
    modesetting.enable = true;
    open = lib.mkOverride 990 (nvidiaPackage ? open && nvidiaPackage ? firmware);
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    powerManagement.enable = true;
    powerManagement.finegrained = true;

    prime = {
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
      offload = {
        enable = lib.mkOverride 990 true;
        enableOffloadCmd = lib.mkIf config.hardware.nvidia.prime.offload.enable true;
      };
    };
  };

  # common/pc/laptop + common/pc/ssd + lenovo/thinkpad
  services.tlp.enable = lib.mkDefault (!config.services.power-profiles-daemon.enable);
  services.fstrim.enable = lib.mkDefault true;
  hardware.trackpoint.enable = lib.mkDefault true;
  hardware.trackpoint.emulateWheel = lib.mkDefault config.hardware.trackpoint.enable;
}
