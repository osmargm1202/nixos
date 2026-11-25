{ config, lib, pkgs, userName, profileName ? null, ... }:

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
  physicalXorgConfig = lib.removePrefix "-config " (lib.findFirst
    (lib.hasPrefix "-config ")
    (throw "ORGM requires the generated Xorg configuration")
    config.services.xserver.displayManager.xserverArgs);
  headlessScreenOptions = pkgs.writeText "orgm-headless-screen-options" ''
    Option "ConnectedMonitor" "DFP-5"
    Option "CustomEDID" "DFP-5:${headlessEdid}"
    Option "MetaModes" "DFP-5: nvidia-auto-select +0+0"
  '';
  headlessXorgConfig = pkgs.runCommand "orgm-headless-xorg.conf" { } ''
    marker='^[[:blank:]]*# orgm-headless-screen-options$'
    test "$(grep -c "$marker" ${lib.escapeShellArg physicalXorgConfig})" -eq 1
    sed "/$marker/r ${headlessScreenOptions}" ${lib.escapeShellArg physicalXorgConfig} > "$out"
  '';
  xorg = pkgs.writeShellScript "orgm-xorg" ''
    # Read kernel connector state before Xorg can force a virtual output.
    # Allow a short window for DisplayPort to report a connected monitor.
    for attempt in {1..8}; do
      for status in /sys/class/drm/card[0-9]*-*/status; do
        [[ -r "$status" && "$(<"$status")" == connected ]] || continue
        connector="''${status%/status}"
        card="''${connector%%-*}"
        if [[ "$(${pkgs.coreutils}/bin/readlink -f "$card/device/driver")" == /sys/bus/pci/drivers/nvidia ]]; then
          echo "ORGM Xorg: using physical monitor (''${connector##*/})" >&2
          exec ${pkgs.xorg-server.out}/bin/X "$@"
        fi
      done
      ${pkgs.coreutils}/bin/sleep 0.25
    done

    args=("$@")
    for ((i = 0; i + 1 < $#; i++)); do
      if [[ "''${args[i]}" == -config && "''${args[i+1]}" == ${lib.escapeShellArg physicalXorgConfig} ]]; then
        args[i+1]=${headlessXorgConfig}
        echo "ORGM Xorg: using headless DP-4 at 144 Hz" >&2
        break
      fi
    done
    exec ${pkgs.xorg-server.out}/bin/X "''${args[@]}"
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
  services.xserver = lib.mkIf (profileName == "hyprland" && config.services.xserver.enable) {
    screenSection = "# orgm-headless-screen-options";
    displayManager.xserverBin = lib.mkOverride 90 "${xorg}";
  };

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
