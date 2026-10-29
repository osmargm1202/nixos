{
  config,
  lib,
  pkgs,
  userName ? "osmarg",
  profileName ? null,
  ...
}:

let
  tty1Autologin = "${pkgs.util-linux}/sbin/agetty --autologin ${userName} --noclear %I $TERM";
  setServerBootDefault = pkgs.writeShellApplication {
    name = "set-server-boot-default";
    runtimeInputs = [
      pkgs.gnused
      pkgs.systemd
    ];
    text = ''
      boot_root="''${SYSTEMD_BOOT_ROOT:-/boot}"
      loader_conf="$boot_root/loader/loader.conf"
      default_entry="$(sed -n 's/^default //p' "$loader_conf")"

      # The systemd-boot builder emits this base filename before this hook runs.
      # Leave non-NixOS defaults untouched rather than pointing at a non-existent
      # specialization.
      if [[ ! "$default_entry" =~ ^(nixos-generation-[0-9]+)(-specialisation-[a-zA-Z0-9_-]+)?\.conf$ ]]; then
        exit 0
      fi

      server_entry="''${BASH_REMATCH[1]}-specialisation-server.conf"
      if [[ -f "$boot_root/loader/entries/$server_entry" ]]; then
        sed -i "s|^default .*|default $server_entry|" "$loader_conf"
        ${lib.optionalString config.boot.loader.efi.canTouchEfiVariables ''
          # An EFI default overrides loader.conf. Update it only during a real
          # host installation, never when exercising a private ESP test tree.
          if [[ -z "''${SYSTEMD_BOOT_ROOT:-}" && -d /sys/firmware/efi/efivars ]]; then
            bootctl --esp-path="$boot_root" set-default "$server_entry"
          fi
        ''}
      fi
    '';
  };
in
{
  # p14s-gen2i-base.nix is selected by nixos/dns/hosts.nix for every Lenovo role.
  imports = [ ../../apps/deskflow.nix ../../apps/nextcloud-server.nix ];

  config = {
    # Retain the current deployment and two rollbacks. Shared sort keys keep the
    # normal, battery, gaming, Windows VFIO, and recovery choices adjacent.
    boot.loader.systemd-boot.configurationLimit = 3;
    boot.loader.systemd-boot = {
      sortKey = "nixos-02-normal";
      extraInstallCommands = "${setServerBootDefault}/bin/set-server-boot-default";
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
        boot.loader.systemd-boot.sortKey = lib.mkForce "nixos-03-gaming";
        services.displayManager.sddm.enable = lib.mkForce false;
        # i3 otherwise enables LightDM by default when SDDM is disabled.
        services.xserver.displayManager.lightdm.enable = lib.mkForce false;
        services.displayManager.autoLogin.enable = lib.mkForce false;
        powerManagement.cpuFreqGovernor = "performance";
        environment.etc."orgm/desktop-profile".text = lib.mkForce "gaming\n";
      }
      // lib.optionalAttrs (profileName == "ryoku") {
        programs.ryoku.enable = lib.mkForce false;
      };
      windows-vfio.configuration = {
        imports = [ ./windows-vfio.nix ];
        environment.etc."orgm/desktop-profile".text = lib.mkForce "windows\n";
        boot.loader.systemd-boot.sortKey = lib.mkForce "nixos-01-windows-vfio";
      };
      battery.configuration = {
        orgm.lenovo.nvidiaDisabled.enable = true;
        boot.loader.systemd-boot.sortKey = lib.mkForce "nixos-04-battery";
        powerManagement.cpuFreqGovernor = "powersave";
        boot.blacklistedKernelModules = [
          "nouveau"
          "nvidia"
          "nvidia_drm"
          "nvidia_modeset"
          "nvidia_uvm"
        ];
        environment.etc."orgm/desktop-profile".text = lib.mkForce "battery\n";
      };
      server.configuration = {
        imports = [ ./windows-vfio.nix ];
        boot.loader.systemd-boot.sortKey = lib.mkForce "nixos-00-server";
        environment.etc."orgm/desktop-profile".text = lib.mkForce "server\n";
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
        services.xserver.displayManager.lightdm.enable = lib.mkForce false;
        services.displayManager.autoLogin.enable = lib.mkForce false;
        services.xserver.enable = lib.mkForce false;
        services.xserver.desktopManager.cinnamon.enable = lib.mkForce false;
        services.desktopManager.gnome.enable = lib.mkForce false;
        services.xserver.windowManager.i3.enable = lib.mkForce false;
        programs.hyprland.enable = lib.mkForce false;
        programs.labwc.enable = lib.mkForce false;
        # Flatpak stays installed in console modes; GNOME no longer supplies
        # its portal once the desktop is disabled.
        xdg.portal = {
          enable = lib.mkDefault true;
          extraPortals = lib.mkDefault [ pkgs.xdg-desktop-portal-gtk ];
        };
        programs.bash.loginShellInit = lib.mkForce ''
          if [[ $- == *i* && -r "$HOME/.bashrc" ]]; then
            . "$HOME/.bashrc"
          fi
        '';
      }
      // lib.optionalAttrs (profileName == "ryoku") {
        programs.ryoku.enable = lib.mkForce false;
      };
    };
  };
}
