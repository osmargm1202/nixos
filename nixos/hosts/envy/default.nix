{ config, lib, pkgs, userName, ... }:
{
  imports = [ ./recovery.nix ./audio.nix ./options.nix ./gpu.nix ./modes.nix ./windows.nix ];
  # Keep the user-selected 6.12 LTS across modes; render preflight guards newer requirements.
  boot.kernelPackages = pkgs.linuxPackages_6_12;
  boot.initrd.kernelModules = [ "i915" ];
  boot.loader.systemd-boot.configurationLimit = 3;
  boot.loader.timeout = lib.mkForce 1;
  # The greeter must not inherit an arbitrary firmware Num Lock state.
  services.displayManager.sddm = {
    autoNumlock = true;
    settings.General.Numlock = "on";
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = [ pkgs.intel-media-driver pkgs.vpl-gpu-rt ];
    extraPackages32 = [ pkgs.driversi686Linux.intel-media-driver ];
  };
  hardware.firmware = [ pkgs.sof-firmware ];

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
