{
  config,
  lib,
  pkgs,
  ...
}:

let
  nvidiaPackage = config.hardware.nvidia.package;
  intelMediaRuntime = pkgs.vpl-gpu-rt or pkgs.onevpl-intel-gpu;
  nvidiaGame = pkgs.writeShellApplication {
    name = "nvidia-game";
    text = ''
      if ! command -v nvidia-offload >/dev/null 2>&1; then
        printf '%s\n' 'NVIDIA PRIME offload is unavailable; refusing to fall back to Intel.' >&2
        exit 1
      fi
      exec nvidia-offload "$@"
    '';
  };
in
{
  imports = [ ../../hardware/kernel/lts.nix ];

  options.orgm.lenovo = {
    windowsVfio.enable = lib.mkEnableOption "exclusive T500 VFIO passthrough for Windows";
    nvidiaDisabled.enable = lib.mkEnableOption "Intel-only boot profile with NVIDIA disabled";
  };

  config = {
    # Local equivalent of nixos-hardware's Lenovo ThinkPad P14s Intel Gen 2
    # profile, kept in-repo so Lenovo carries its own host-specific GPU setup.
    boot.blacklistedKernelModules = lib.optionals (!config.hardware.enableRedistributableFirmware) [
      "ath3k"
    ];
    hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
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

    # PRIME owns the T500 unless another boot specialisation claims or disables it.
    services.xserver.videoDrivers = lib.mkIf (!(config.orgm.lenovo.windowsVfio.enable || config.orgm.lenovo.nvidiaDisabled.enable)) [ "nvidia" ];
    environment.systemPackages = lib.mkIf (!(config.orgm.lenovo.windowsVfio.enable || config.orgm.lenovo.nvidiaDisabled.enable)) [ nvidiaPackage nvidiaGame ];
    hardware.nvidia = lib.mkIf (!(config.orgm.lenovo.windowsVfio.enable || config.orgm.lenovo.nvidiaDisabled.enable)) {
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

    services.tlp.enable = lib.mkDefault (!config.services.power-profiles-daemon.enable);
    services.fstrim.enable = lib.mkDefault true;
    hardware.trackpoint.enable = lib.mkDefault true;
    hardware.trackpoint.emulateWheel = lib.mkDefault config.hardware.trackpoint.enable;
  };
}
