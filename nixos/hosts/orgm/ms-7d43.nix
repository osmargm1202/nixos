{ lib, ... }:

{
  imports = [ ./audio.nix ];

  # MSI MS-7D43 desktop: Intel Alder Lake CPU, NVIDIA primary GPU, NVMe SSD.
  # Keep generated disk/module detection in hardware-configuration.nix; this file
  # carries stable board/model tuning that should survive regenerate-config.
  hardware.enableRedistributableFirmware = true;

  services.fwupd.enable = true;
  services.fstrim.enable = lib.mkDefault true;
  services.smartd.enable = lib.mkDefault true;

  # Load NVIDIA KMS in initrd so Plymouth can render on the primary GPU early.
  boot.initrd.kernelModules = [
    "nvidia"
    "nvidia_modeset"
    "nvidia_uvm"
    "nvidia_drm"
  ];

  boot.kernelParams = lib.mkAfter [ "nvidia-drm.modeset=1" ];
  boot.extraModprobeConfig = lib.mkAfter ''
    options nvidia_drm modeset=1
  '';

  # The base desktop configuration is ORGM's normal boot mode. Its server
  # specialization retains the same board support and networking while
  # replacing every graphical login path with the server role.
  boot.loader.systemd-boot.sortKey = "nixos-00-normal";
  specialisation.server.configuration = {
    imports = [ ../../server.nix ];
    boot.loader.systemd-boot.sortKey = lib.mkForce "nixos-01-server";
    systemd.defaultUnit = "multi-user.target";

    services = {
      displayManager = {
        sddm.enable = lib.mkForce false;
        autoLogin.enable = lib.mkForce false;
      };
      xserver = {
        enable = lib.mkForce false;
        desktopManager.cinnamon.enable = lib.mkForce false;
        desktopManager.gnome.enable = lib.mkForce false;
        windowManager.i3.enable = lib.mkForce false;
        displayManager.startx.enable = lib.mkForce false;
      };
    };
    programs = {
      hyprland.enable = lib.mkForce false;
      labwc.enable = lib.mkForce false;
      xwayland.enable = lib.mkForce false;
      bash.loginShellInit = lib.mkForce ''
        if [[ $- == *i* && -r "$HOME/.bashrc" ]]; then
          . "$HOME/.bashrc"
        fi
      '';
    };
  };
}
