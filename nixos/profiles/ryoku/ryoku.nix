{ config, lib, pkgs, inputs, userName ? "osmarg", ... }:
let
  enabled = config.programs.ryoku.enable;
  ryokuPackages = inputs.ryoku.packages.${pkgs.stdenv.hostPlatform.system};
  materializer = ryokuPackages.ryoku-materialize;
  prepare = pkgs.writeShellApplication {
    name = "orgm-ryoku-prepare";
    runtimeInputs = [ pkgs.coreutils ];
    text = builtins.readFile ./prepare.sh;
  };
  sharedHelpers = [
    "hypr-rofi-calc" "hypr-rofi-open-file" "hypr-rofi-open-file-dir"
    "hypr-rofi-open-file-terminal" "hypr-kill-windows"
  ];
  personalHelpers = [
    "hypr-obsidian-open-or-focus" "hypr-pi-prompt" "hypr-rofi-ssh-host"
  ];
  helperFiles = root: names: lib.genAttrs (map (name: ".local/bin/${name}") names) (
    target: { source = root + "/${builtins.baseNameOf target}"; executable = true; }
  );
in {
  imports = [ inputs.ryoku.nixosModules.default ../keyring-never-ask.nix ../../print/printer.nix ];

  config = lib.mkMerge [
    {
      programs.ryoku = {
        enable = lib.mkDefault true;
        updateFlake = "/home/${userName}/Hobby/nixos";
        updateInput = "ryoku";
      };
      # Console boot modes retain Flatpak support while the Ryoku module is off.
      xdg.portal = {
        enable = lib.mkDefault true;
        extraPortals = lib.optionals (!enabled) [ pkgs.xdg-desktop-portal-gtk ];
        config.common.default = lib.mkDefault [ "gtk" ];
      };
    }
    (lib.mkIf enabled {
      # Ryoku enables Docker; Podman keeps its native CLI without sharing Docker's socket.
      virtualisation.podman.dockerCompat = lib.mkForce false;
      virtualisation.podman.dockerSocket.enable = lib.mkForce false;
      # X11 greeter avoids the Lenovo Wayland greeter failure; the desktop is Wayland.
      services.xserver.enable = lib.mkDefault true;
      services.displayManager.sddm = {
        enable = lib.mkDefault true;
        package = pkgs.kdePackages.sddm;
        wayland.enable = false;
      };
      services.displayManager.defaultSession = "hyprland";
      environment.localBinInPath = true;
      environment.systemPackages = with pkgs; [
        rofi rofi-calc rofimoji grim slurp swappy playerctl xdg-utils
        nautilus gnome-text-editor evince loupe file-roller
        gnome-online-accounts-gtk pavucontrol wl-screenrec ffmpeg libqalculate woomer
      ];
      xdg.mime.defaultApplications."inode/directory" = "org.gnome.Nautilus.desktop";
      services.gnome.gnome-online-accounts.enable = true;

      systemd.user.services.ryoku-materialize = {
        unitConfig.ConditionUser = userName;
        serviceConfig.ExecStartPre = "${prepare}/bin/orgm-ryoku-prepare";
        restartTriggers = [ prepare ];
      };
      systemd.user.services.orgm-keyring-never-ask = {
        after = [ "ryoku-materialize.service" ];
        before = [ "ryoku-shell.service" ];
      };

      home-manager.users.${userName} = { lib, ... }: {
        home.file =
          helperFiles ../../../dotfiles/config/profiles/hyprland/.local/bin sharedHelpers
          // helperFiles ../../../dotfiles/config/users/osmarg/profiles/hyprland/.local/bin personalHelpers
          // {
            ".config/orgm-ryoku/osmarg-keybindings.lua".source =
              ../../../dotfiles/config/users/osmarg/profiles/hyprland/.config/hypr/lua/keybindings.lua;
          };
        # Materialize before the first login, rather than waiting for a desktop
        # that cannot yet start without its Hyprland configuration.
        home.activation.ryokuDesktop = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
          $DRY_RUN_CMD ${prepare}/bin/orgm-ryoku-prepare
          $DRY_RUN_CMD ${materializer}/bin/ryoku-materialize
        '';
      };
      assertions = [ {
        assertion = userName == "osmarg";
        message = "The personal Ryoku profile belongs to Osmarg; define another user's shortcuts separately.";
      } ];
    })
  ];
}
