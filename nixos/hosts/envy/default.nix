{ config, lib, pkgs, userName, ... }:
{
  imports = [ ../../apps/deskflow.nix ];
  # Phase one: normal desktop only, without inheriting Lenovo specialisations.
  boot.kernelPackages = pkgs.linuxPackages_6_12;
  boot.initrd.kernelModules = [ "i915" ];
  boot.loader.systemd-boot.configurationLimit = 3;
  boot.loader.timeout = lib.mkForce 5;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = [ pkgs.intel-media-driver pkgs.vpl-gpu-rt ];
    extraPackages32 = [ pkgs.driversi686Linux.intel-media-driver ];
  };
  hardware.firmware = [ pkgs.sof-firmware ];
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    # MX250 is Pascal: current stable/open drivers do not support it.
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
    open = false;
    modesetting.enable = true;
    nvidiaSettings = true;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    prime = {
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:2:0:0";
      offload.enable = true;
      offload.enableOffloadCmd = true;
    };
  };

  zramSwap = { enable = true; algorithm = "zstd"; memoryPercent = 50; };
  services.fstrim.enable = true;
  services.btrfs.autoScrub.enable = true;
  services.smartd.enable = true;
  networking.networkmanager.wifi.powersave = false;

  services.openssh.settings = {
    PasswordAuthentication = lib.mkForce false;
    KbdInteractiveAuthentication = false;
  };
  users.users.${userName} = {
    openssh.authorizedKeys.keys = [ (builtins.readFile ./authorized_keys) ];
    # The installer sets a private initial password in /etc/shadow afterwards.
    # A rebuild must neither embed a password in the store nor reset it.
    initialHashedPassword = "!";
  };
  environment.systemPackages = with pkgs; [
    pciutils usbutils smartmontools nvme-cli btrfs-progs
    mesa-demos vulkan-tools libva-utils alsa-utils v4l-utils ethtool
  ];
}
