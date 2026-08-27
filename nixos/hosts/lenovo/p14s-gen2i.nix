{
  config,
  lib,
  pkgs,
  userName ? "osmarg",
  ...
}:

let
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
  # p14s-gen2i-base.nix is selected by nixos/hosts.nix for every Lenovo role.
  imports = [ ../../deskflow.nix ];

  config = {
    # Retain the current deployment and two rollbacks. Shared sort keys keep the
    # normal, battery, gaming, Windows VFIO, and recovery choices adjacent.
    boot.loader.systemd-boot.configurationLimit = 3;
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
  };
}
