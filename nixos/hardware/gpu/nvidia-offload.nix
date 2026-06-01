{ config, ... }:

{
  services.xserver.videoDrivers = [ "nvidia" ];
  services.upower.enable = true;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;

    prime.offload = {
      enable = true;
      enableOffloadCmd = true;
    };
  };
}
