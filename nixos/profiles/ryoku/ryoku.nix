{ config, lib, pkgs, inputs, userName ? "osmarg", ... }:
let
  enabled = config.programs.ryoku.enable;
  userAutostart = config.orgm.user.autostart;
  hasProgram = name: builtins.elem name config.orgm.user.programs;
  nativeSession = {
    required = [];
    # Explicit retirement happens once; later Session edits remain user-owned.
    retired = [ "tailscale systray --theme light" "tailscale systray"
      "syncthingtray --single-instance --wait" "syncthingtray"
      "blueman-applet" "nm-applet" "nm-applet --indicator" "print-applet" ]
      ++ lib.optional (!hasProgram "nextcloud") "nextcloud --background";
    optional = userAutostart;
    desktop = builtins.fromJSON (builtins.readFile
      ../../../dotfiles/config/profiles/ryoku/.config/orgm-ryoku/native-keybinds.json);
  };
  maskedAutostart = [
    "tailscale-systray.desktop" "syncthingtray.desktop" "blueman.desktop"
    "nm-applet.desktop" "print-applet.desktop"
    "Nextcloud.desktop" "com.nextcloud.desktopclient.nextcloud.desktop"
  ];
  legacySyncthingUnits = [
    ".config/systemd/user/default.target.wants/syncthing.service"
    ".config/systemd/user/syncthing.service"
  ];
  unitCleanupManifest = pkgs.writeText "ryoku-syncthing-unit-cleanup.json" (builtins.toJSON {
    packageUnits = legacySyncthingUnits;
  });
  cleanupManifest = pkgs.writeText "ryoku-desktop-cleanup.json" (builtins.toJSON {
    autostart = maskedAutostart;
    packageUnits = legacySyncthingUnits;
    files = [ {
      target = ".local/share/nautilus/scripts/Set as Hyprland Wallpaper";
      sources = [ "${../../../dotfiles/config/profiles/hyprland/.local/share/nautilus/scripts}/Set as Hyprland Wallpaper" ];
    } ];
  });
  providerCompat = import ./provider-compat.nix { inherit inputs pkgs lib; };
  ryokuPackages = providerCompat.packages;
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
  lockPam = pkgs.writeShellScript "orgm-ryoku-lock-pam" ''
    set -eu
    pam_dir="$HOME/.local/share/quickshell-lockscreen/assets/pam"
    test -d "$pam_dir"
    cat > "$pam_dir/ryoku-lock" <<'EOF'
#%PAM-1.0
# Independent fingerprint conversation; Ryoku controls whether to start it.
auth required ${pkgs.fprintd}/lib/security/pam_fprintd.so timeout=-1
account required ${config.security.pam.package}/lib/security/pam_unix.so
EOF
    cat > "$pam_dir/ryoku-lock-pw" <<'EOF'
#%PAM-1.0
# Independent password conversation, kept available alongside fingerprint.
auth required ${config.security.pam.package}/lib/security/pam_unix.so
account required ${config.security.pam.package}/lib/security/pam_unix.so
EOF
    chmod 600 "$pam_dir/ryoku-lock" "$pam_dir/ryoku-lock-pw"
  '';
  prepare = pkgs.writeShellApplication {
    name = "orgm-ryoku-prepare";
    runtimeInputs = [ pkgs.coreutils pkgs.gnugrep pkgs.systemd pkgs.jq pkgs.python3 ];
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
  imports = [ providerCompat.module ../../print/printer.nix ./runtime-path.nix ];

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
      # The selected sync backend also survives console/server specialisations.
      home-manager.users.${userName} = { lib, ... }: {
        # Keep the daemon independent of the tray, with native state discovery.
        # No generated folders, credentials, GUI address or peer overrides.
        systemd.user.services.syncthing = lib.mkIf (hasProgram "syncthing") {
          Unit = {
            Description = "Syncthing background synchronization";
            StartLimitIntervalSec = 60;
            StartLimitBurst = 4;
          };
          Service = {
            ExecStart = "${pkgs.syncthing}/bin/syncthing serve --no-browser --no-restart";
            Restart = "on-failure";
            RestartSec = 1;
            SuccessExitStatus = [ 3 4 ];
            RestartForceExitStatus = [ 3 4 ];
            MemoryDenyWriteExecute = true;
            NoNewPrivileges = true;
            SystemCallArchitectures = "native";
          };
          Install.WantedBy = [ "default.target" ];
        };
        home.activation.ryokuSyncthingUnitCleanup = lib.mkIf (hasProgram "syncthing") (
          lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
            $DRY_RUN_CMD ${pkgs.python3}/bin/python3 ${./cleanup.py} "$HOME" \
              "''${XDG_STATE_HOME:-$HOME/.local/state}/orgm-ryoku" ${unitCleanupManifest}
          ''
        );
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
      # Hub owns enrollment and the lockscreen fingerprint preference.
      services.fprintd.enable = true;
      # Ryoku owns Bluetooth and Wi-Fi UI; their system backends stay enabled.
      services.blueman.enable = lib.mkForce false;
      programs.nm-applet.enable = lib.mkForce false;
      security.pam.services.sddm.enableGnomeKeyring = true;
      security.pam.services.login.enableGnomeKeyring = true;
      # The upstream drop-in otherwise overrides Lenovo's hardware lid policy.
      environment.etc."systemd/logind.conf.d/10-ryoku-lid.conf".enable = lib.mkForce false;
      environment.localBinInPath = true;
      environment.systemPackages = with pkgs; [
        folderIcons pkgs.fprintd
        rofi rofimoji
        nautilus gnome-text-editor evince loupe file-roller
        gnome-online-accounts-gtk libqalculate woomer
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
        serviceConfig.ExecStartPost = lib.mkAfter [ "${lockPam}" ];
        restartTriggers = [ prepare ];
      };
      systemd.user.services.ryogami.path = lib.mkBefore [ folderIcons pkgs.fprintd ];
      systemd.user.services.ryoku-shell.path = lib.mkBefore [ folderIcons pkgs.fprintd ];

      home-manager.users.${userName} = { config, lib, ... }: {
        # XDG entries otherwise launch duplicate UI outside Hub's Session list.
        imports = [ {
          xdg.configFile = lib.genAttrs (map (name: "autostart/${name}") maskedAutostart) (path: {
            force = true;
            text = "[Desktop Entry]\nType=Application\nName=${builtins.baseNameOf path}\nHidden=true\n";
          });
        } ];
        home.activation.ryokuDesktopCleanup = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
          $DRY_RUN_CMD ${pkgs.python3}/bin/python3 ${./cleanup.py} "$HOME" \
            "''${XDG_STATE_HOME:-$HOME/.local/state}/orgm-ryoku" ${cleanupManifest}
        '';
        xdg.configFile."orgm-ryoku/cleanup-manifest.json".source = cleanupManifest;
        services.blueman-applet.enable = lib.mkForce false;
        services.network-manager-applet.enable = lib.mkForce false;
        xdg.configFile."orgm-ryoku/native-session.json" = {
          force = true; # Generated migration metadata, not the user's Hub store.
          text = builtins.toJSON nativeSession;
        };
        xdg.configFile."orgm-ryoku/native-session.py".source = ./native-session.py;
        services.dunst.enable = lib.mkForce false;
        services.mako.enable = lib.mkForce false;
        home.file = helperFiles ../../../dotfiles/config/users/osmarg/profiles/hyprland/.local/bin personalHelpers;
        # Stable active-generation helper: the initial editable overlay must
        # not freeze a collectable package path or need reimposition on updates.
        xdg.configFile."orgm-ryoku/matugen-config.toml".text = builtins.replaceStrings
          [ "&& ryoku-cmd-folders;" ]
          [ "&& /run/current-system/sw/bin/ryoku-cmd-folders;" ]
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
            # Activation does not inherit a GTK application's schema wrapper.
            GSETTINGS_SCHEMA_DIR="${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}/glib-2.0/schemas" \
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
