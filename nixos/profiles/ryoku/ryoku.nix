{ config, lib, pkgs, inputs, userName ? "osmarg", ... }:
let
  enabled = config.programs.ryoku.enable;
  ryokuPackages = inputs.ryoku.packages.${pkgs.stdenv.hostPlatform.system};
  materializer = ryokuPackages.ryoku-materialize;
  # The upstream helper still assumes Arch's /usr/share/icons. Package its
  # native implementation with the Nix Papirus path and an explicit runtime.
  folderIcons = pkgs.runCommand "ryoku-folder-icons" {
    nativeBuildInputs = [ pkgs.makeWrapper ];
    meta.priority = -10;
  } ''
    install -Dm755 ${inputs.ryoku.outPath}/ryoku/shell/scripts/ryoku-cmd-folders "$out/bin/ryoku-cmd-folders"
    substituteInPlace "$out/bin/ryoku-cmd-folders" \
      --replace-fail '/usr/share/icons/Papirus' '${pkgs.papirus-icon-theme}/share/icons/Papirus'
    patchShebangs "$out/bin"
    wrapProgram "$out/bin/ryoku-cmd-folders" --prefix PATH : ${lib.makeBinPath [
      pkgs.coreutils pkgs.gawk pkgs.gnused pkgs.util-linux pkgs.glib pkgs.gtk3
    ]}
  '';
  prepare = pkgs.writeShellApplication {
    name = "orgm-ryoku-prepare";
    runtimeInputs = [ pkgs.coreutils pkgs.gnugrep pkgs.systemd pkgs.jq ];
    text = builtins.readFile ./prepare.sh;
  };
  rofiTheme = pkgs.writeShellApplication {
    name = "orgm-ryoku-rofi-theme";
    runtimeInputs = [ pkgs.coreutils pkgs.jq ];
    text = builtins.readFile ./rofi-theme.sh;
  };
  # These add personal focus/SSH/Pi workflows, rather than another desktop UI.
  personalHelpers = [
    "hypr-obsidian-open-or-focus" "hypr-pi-prompt" "hypr-rofi-ssh-host"
  ];
  helperFiles = root: names: lib.genAttrs (map (name: ".local/bin/${name}") names) (
    target: { source = root + "/${builtins.baseNameOf target}"; executable = true; }
  );
in {
  imports = [ inputs.ryoku.nixosModules.default ../../print/printer.nix ];

  # Upstream includes Mako as a shell probe, but publishing its D-Bus service
  # lets it claim notifications before Quickshell. Filter the merged package
  # list only while Ryoku is enabled; other desktops retain their daemons.
  options.environment.systemPackages = lib.mkOption {
    apply = packages: if enabled then lib.filter (
      package: !builtins.elem (lib.getName package) [ "mako" "dunst" ]
    ) packages else packages;
  };

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
      # PAM can unlock an encrypted login keyring only after password login.
      services.displayManager.autoLogin.enable = lib.mkForce false;
      security.pam.services.sddm.enableGnomeKeyring = true;
      security.pam.services.login.enableGnomeKeyring = true;
      # The upstream drop-in otherwise overrides Lenovo's hardware lid policy.
      environment.etc."systemd/logind.conf.d/10-ryoku-lid.conf".enable = lib.mkForce false;
      environment.localBinInPath = true;
      environment.systemPackages = with pkgs; [
        folderIcons
        rofi rofi-calc rofimoji grim slurp swappy playerctl xdg-utils
        nautilus gnome-text-editor evince loupe file-roller
        gnome-online-accounts-gtk pavucontrol wl-screenrec ffmpeg libqalculate woomer
      ];
      xdg.mime.defaultApplications."inode/directory" = "org.gnome.Nautilus.desktop";
      services.gnome.gnome-online-accounts.enable = true;
      programs.nautilus-open-any-terminal = {
        enable = true;
        terminal = "kitty";
      };

      systemd.user.services.ryoku-materialize = {
        unitConfig.ConditionUser = userName;
        serviceConfig.ExecStartPre = "${prepare}/bin/orgm-ryoku-prepare";
        restartTriggers = [ prepare ];
      };
      systemd.user.services.ryogami.path = lib.mkBefore [ folderIcons ];
      systemd.user.services.ryoku-shell.path = lib.mkBefore [ folderIcons ];

      home-manager.users.${userName} = { config, lib, ... }: {
        services.dunst.enable = lib.mkForce false;
        services.mako.enable = lib.mkForce false;
        home.file = helperFiles ../../../dotfiles/config/users/osmarg/profiles/hyprland/.local/bin personalHelpers;
        # Also make the palette hook deterministic in an already-running
        # session; this overlay survives Ryoku materialization and updates.
        xdg.configFile."orgm-ryoku/matugen-config.toml".text = builtins.replaceStrings
          [ "&& ryoku-cmd-folders;" ]
          [ "&& ${folderIcons}/bin/ryoku-cmd-folders;" ]
          (builtins.readFile "${inputs.ryoku.outPath}/ryoku/shell/matugen/config.toml");
        # Materialize before the first login, rather than waiting for a desktop
        # that cannot yet start without its Hyprland configuration.
        home.activation.ryokuDesktop = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
          $DRY_RUN_CMD ${pkgs.systemd}/bin/systemctl --user stop orgm-ryoku-rofi-theme-live.path 2>/dev/null || true
          $DRY_RUN_CMD ${prepare}/bin/orgm-ryoku-prepare
          $DRY_RUN_CMD ${materializer}/bin/ryoku-materialize
          $DRY_RUN_CMD ${rofiTheme}/bin/orgm-ryoku-rofi-theme
        '';
        home.activation.ryokuFolderIcons = lib.hm.dag.entryAfter [ "ryokuDesktop" ] ''
          $DRY_RUN_CMD ${folderIcons}/bin/ryoku-cmd-folders
          state="''${XDG_STATE_HOME:-$HOME/.local/state}/orgm-ryoku"
          if [ ! -f "$state/folder-icons-selected" ]; then
            $DRY_RUN_CMD ${pkgs.glib}/bin/gsettings set org.gnome.desktop.interface icon-theme ryoku-folders
            $DRY_RUN_CMD mkdir -p "$state"
            $DRY_RUN_CMD touch "$state/folder-icons-selected"
          fi
        '';
        systemd.user.services.orgm-ryoku-rofi-theme = {
          Unit.Description = "Apply Ryoku palette to Rofi menus";
          Service = {
            Type = "oneshot";
            ExecStart = "${rofiTheme}/bin/orgm-ryoku-rofi-theme";
          };
        };
        systemd.user.paths.orgm-ryoku-rofi-theme = {
          Unit = {
            Description = "Watch Ryoku palette changes for Rofi";
            PartOf = [ "graphical-session.target" ];
          };
          Path = {
            PathChanged = "${config.xdg.cacheHome}/ryoku/colors.json";
            Unit = "orgm-ryoku-rofi-theme.service";
          };
          Install.WantedBy = [ "graphical-session.target" ];
        };
      };
      assertions = [ {
        assertion = userName == "osmarg";
        message = "The personal Ryoku profile belongs to Osmarg; define another user's shortcuts separately.";
      } ];
    })
  ];
}
