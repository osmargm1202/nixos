{ config, lib, options, pkgs, ... }:
let
  bootMount = if config.boot.loader.systemd-boot.xbootldrMountPoint != null
    then config.boot.loader.systemd-boot.xbootldrMountPoint
    else config.boot.loader.efi.efiSysMountPoint;
  console = {
    programs.hyprland.enable = lib.mkForce false;
    programs.sway.enable = lib.mkForce false;
    programs.niri.enable = lib.mkForce false;
    programs.labwc.enable = lib.mkForce false;
    services.displayManager.sddm.enable = lib.mkForce false;
    services.displayManager.autoLogin.enable = lib.mkForce false;
    services.xserver = {
      enable = lib.mkForce false;
      displayManager.lightdm.enable = lib.mkForce false;
      desktopManager.cinnamon.enable = lib.mkForce false;
      windowManager.i3.enable = lib.mkForce false;
      displayManager.startx.enable = lib.mkForce false;
    };
    services.desktopManager.gnome.enable = lib.mkForce false;
    services.sunshine.enable = lib.mkForce false;
  } // lib.optionalAttrs (options.programs ? ryoku) {
    programs.ryoku.enable = lib.mkForce false;
  };
in {
  boot.loader.systemd-boot = {
    sortKey = "nixos";
    # Apply to every retained generation, including older bootspec sort keys.
    extraInstallCommands = ''
      ${pkgs.python3}/bin/python3 ${./boot-menu-order.py} ${lib.escapeShellArg "${bootMount}/loader/entries"}
    '';
  };
  specialisation = {
    gaming.configuration = lib.mkMerge [ console {
      orgm.envy.mode = lib.mkForce "gaming";
      orgm.gaming.gamescopeTty1.enable = true;
      powerManagement.cpuFreqGovernor = "performance";
      environment.etc."orgm/desktop-profile".text = lib.mkForce "gaming\n";
    }];
    windows-vfio.configuration = {
      orgm.envy.mode = lib.mkForce "windows";
      environment.etc."orgm/desktop-profile".text = lib.mkForce "windows\n";
    };
    server.configuration = lib.mkMerge [ console {
      orgm.envy.mode = lib.mkForce "server";
      environment.etc."orgm/desktop-profile".text = lib.mkForce "server\n";
      systemd.defaultUnit = "multi-user.target";
      programs.xwayland.enable = lib.mkForce false;
      programs.steam.enable = lib.mkForce false;
      programs.steam.gamescopeSession.enable = lib.mkForce false;
      programs.gamemode.enable = lib.mkForce false;
      programs.bash.loginShellInit = lib.mkForce ''
        if [[ $- == *i* && -r "$HOME/.bashrc" ]]; then
          . "$HOME/.bashrc"
        fi
      '';
    }];
  };
}
