{ lib, pkgs, userName, profileName ? null, ... }:

let
  # EDID for the headless Xorg output. The preferred timing is 1920x1080 at
  # 144 Hz (CVT reduced blanking, 346.54 MHz). The second timing is 1080p60.
  headlessEdid = pkgs.runCommand "orgm-1080p144-edid.bin" {
    nativeBuildInputs = [ pkgs.xxd ];
  } ''
    xxd -r -p > "$out" <<'EDID'
    00ffffffffffff0031d8000000000000
    05160104a5321c78e25ec0a4594a9825
    205054000000d1c00101010101010101
    0101010101015e8780a070384d403020
    3500f4191100001a023a801871382d40
    582c4500f4191100001e000000fd003b
    9142a823010a202020202020000000fc
    004f52474d20464844203134340a009e
    EDID
  '';
in
{
  imports = [ ./audio.nix ./i3-session.nix ./web-panels.nix ../../apps/youtube-send.nix ];


  # MSI MS-7D43 desktop: Intel Alder Lake CPU, NVIDIA primary GPU, NVMe SSD.
  # Keep generated disk/module detection in hardware-configuration.nix; this file
  # carries stable board/model tuning that should survive regenerate-config.
  hardware.enableRedistributableFirmware = true;

  services.fwupd.enable = true;
  services.fstrim.enable = lib.mkDefault true;
  services.smartd.enable = lib.mkDefault true;

  # This desktop should not have games terminated by the shared EarlyOOM policy.
  services.earlyoom.enable = lib.mkForce false;

  # Temporary server use: boot straight into the lightweight i3 (X11) session
  # so Sunshine, Syncthing, Nextcloud and Tailscale come up unattended.
  # Hyprland stays selectable from SDDM after logging out.
  services.displayManager = lib.mkIf (profileName == "hyprland") {
    autoLogin = {
      enable = true;
      user = userName;
    };
    defaultSession = lib.mkForce "orgm-i3";
  };
  # Xorg exposes DFP-5 as DP-4, including headless boots for Sunshine.
  # nvidia-auto-select chooses the preferred timing from the EDID.
  services.xserver.screenSection = lib.mkIf (profileName == "hyprland") ''
    Option "ConnectedMonitor" "DFP-5"
    Option "CustomEDID" "DFP-5:${headlessEdid}"
    Option "MetaModes" "DFP-5: nvidia-auto-select +0+0"
  '';

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
  boot.loader.systemd-boot.configurationLimit = 2;
  boot.loader.systemd-boot.sortKey = "nixos-00-normal";
  specialisation.server.configuration = {
    imports = [ ../../profiles/server.nix ];
    boot.loader.systemd-boot.sortKey = lib.mkForce "nixos-01-server";
    systemd.defaultUnit = "multi-user.target";

    services = {
      displayManager = {
        sddm.enable = lib.mkForce false;
        autoLogin.enable = lib.mkForce false;
      };
      desktopManager.gnome.enable = lib.mkForce false;
      xserver = {
        enable = lib.mkForce false;
        desktopManager.cinnamon.enable = lib.mkForce false;
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
  } // lib.optionalAttrs (profileName == "ryoku") {
    programs.ryoku.enable = lib.mkForce false;
    programs.niri.enable = lib.mkForce false;
  };
}
// lib.optionalAttrs (builtins.elem profileName [ "gnome" "hyprland" "i3" "labwc" ]) {
  orgm.sddm = {
    profile = lib.mkDefault "qylock";
    qylockTheme = lib.mkDefault "star-rail";
  };
}
