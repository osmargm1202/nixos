{
  config,
  lib,
  pkgs,
  userName ? "osmarg",
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
  tty1Autologin = "${pkgs.util-linux}/sbin/agetty --autologin ${userName} --noclear %I $TERM";
  setVfioBootDefault = pkgs.writeShellApplication {
    name = "set-vfio-boot-default";
    runtimeInputs = [ pkgs.gnused ];
    text = ''
      boot_root="''${SYSTEMD_BOOT_ROOT:-/boot}"
      loader_conf="$boot_root/loader/loader.conf"
      default_entry="$(sed -n 's/^default //p' "$loader_conf")"

      # The systemd-boot builder emits this base filename before this hook runs.
      # Leave non-NixOS defaults untouched rather than pointing at a non-existent
      # specialization.
      if [[ ! "$default_entry" =~ ^nixos-generation-[0-9]+\.conf$ ]]; then
        exit 0
      fi

      vfio_entry="''${default_entry%.conf}-specialisation-windows-vfio.conf"
      if [[ -f "$boot_root/loader/entries/$vfio_entry" ]]; then
        sed -i "s|^default .*|default $vfio_entry|" "$loader_conf"
      fi
    '';
  };
in
{
  imports = [
    # Keep every graphical Lenovo profile on the stable LTS kernel line.
    ../../hardware/kernel/lts.nix
    ../../deskflow.nix
  ];

  options.orgm.lenovo = {
    windowsVfio.enable = lib.mkEnableOption "exclusive T500 VFIO passthrough for Windows";
    nvidiaDisabled.enable = lib.mkEnableOption "Intel-only boot profile with NVIDIA disabled";
  };

  config = {
  # Retain the current deployment and two rollbacks. Shared sort keys keep the
  # normal, battery, gaming, Windows VFIO, and recovery choices adjacent.
  boot.loader.systemd-boot.configurationLimit = 3;

  # systemd-boot's normal NixOS builder always writes the base generation as
  # its default. Run a testable post-install hook that selects the matching
  # Windows VFIO entry only when that entry exists.
  boot.loader.systemd-boot = {
    sortKey = "nixos-01-normal";
    extraInstallCommands = "${setVfioBootDefault}/bin/set-vfio-boot-default";
  };

  # Desktop profiles without a display manager start from tty1; SDDM profiles
  # use its equivalent auto-login path. Both land directly in the selected
  # normal, battery, or Windows session without exposing other VTs.
  systemd.services = {
    "getty@tty1".serviceConfig.ExecStart = [
      ""
      tty1Autologin
    ];
    "autovt@tty1".serviceConfig.ExecStart = [
      ""
      tty1Autologin
    ];
  };
  services.displayManager.autoLogin = {
    enable = true;
    user = userName;
  };

  specialisation = {
    gaming.configuration = {
      orgm.gaming.gamescopeTty1.enable = true;
      boot.loader.systemd-boot.sortKey = lib.mkForce "nixos-02-gaming";
      services.displayManager.sddm.enable = lib.mkForce false;
      services.displayManager.autoLogin.enable = lib.mkForce false;
      powerManagement.cpuFreqGovernor = "performance";
    };
    windows-vfio.configuration = {
      imports = [ ./windows-vfio.nix ];
      boot.loader.systemd-boot.sortKey = lib.mkForce "nixos-00-windows-vfio";
    };
    battery.configuration = {
      orgm.lenovo.nvidiaDisabled.enable = true;
      boot.loader.systemd-boot.sortKey = lib.mkForce "nixos-03-battery";
      powerManagement.cpuFreqGovernor = "powersave";
      boot.blacklistedKernelModules = [ "nouveau" "nvidia" "nvidia_drm" "nvidia_modeset" "nvidia_uvm" ];
    };
    server.configuration = {
      boot.loader.systemd-boot.sortKey = lib.mkForce "nixos-04-server";
      systemd.services = {
        "getty@tty1".serviceConfig.ExecStart = lib.mkForce [
          ""
          "${pkgs.util-linux}/sbin/agetty --noclear --keep-baud %I 115200,38400,9600 $TERM"
        ];
        "autovt@tty1".serviceConfig.ExecStart = lib.mkForce [
          ""
          "${pkgs.util-linux}/sbin/agetty --noclear %I $TERM"
        ];
      };
      systemd.defaultUnit = "multi-user.target";
      services.openssh.enable = true;
      networking.networkmanager.enable = true;
      services.displayManager.sddm.enable = lib.mkForce false;
      services.displayManager.autoLogin.enable = lib.mkForce false;
      services.xserver.enable = lib.mkForce false;
      services.xserver.desktopManager.cinnamon.enable = lib.mkForce false;
      services.desktopManager.gnome.enable = lib.mkForce false;
      services.xserver.windowManager.i3.enable = lib.mkForce false;
      programs.hyprland.enable = lib.mkForce false;
      programs.labwc.enable = lib.mkForce false;
      programs.bash.loginShellInit = lib.mkForce ''
        if [[ $- == *i* && -r "$HOME/.bashrc" ]]; then
          . "$HOME/.bashrc"
        fi
      '';
    };
  };

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

  # common/pc/laptop + common/pc/ssd + lenovo/thinkpad
  services.tlp.enable = lib.mkDefault (!config.services.power-profiles-daemon.enable);
  services.fstrim.enable = lib.mkDefault true;
  hardware.trackpoint.enable = lib.mkDefault true;
  hardware.trackpoint.emulateWheel = lib.mkDefault config.hardware.trackpoint.enable;
  };
}
