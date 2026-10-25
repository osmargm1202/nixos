# Package/service integration only. Dotfiles are read from the checkout by
# orgm-dot at runtime, seeded once as writable copies, and updated explicitly.
{ config, pkgs, lib, userName ? "osmarg", profileName ? "hyprland", ... }:
let
  hostName = config.networking.hostName;
  programs = config.orgm.user.programs or [ ];
  programEnabled = name: builtins.elem name programs;
  ryokuEnabled = profileName == "ryoku" && (config.programs.ryoku.enable or false);
  retireOrgmTrays = hostName == "orgm" && profileName == "hyprland";
  retiredTrayNames = [ "tailscale-systray.desktop" "syncthingtray.desktop" ];
  retiredTrayManifest = pkgs.writeText "orgm-retired-trays.json" (builtins.toJSON {
    autostart = retiredTrayNames;
    packageUnits = [
      ".config/systemd/user/default.target.wants/syncthing.service"
      ".config/systemd/user/syncthing.service"
    ];
  });
  orgmaiPackage = pkgs.callPackage ./orgm/orgm-ai.nix { };
  dotPackage = pkgs.callPackage ./orgm/orgm-dot.nix { };
  contextJSON = builtins.toJSON {
    repository = config.orgm.dotfiles.repository;
    user = userName;
    host = hostName;
    profile = if ryokuEnabled then "ryoku" else if profileName == "ryoku" then "terminal" else profileName;
    inherit programs;
  };
  contextFile = pkgs.writeText "orgm-dot-context.json" contextJSON;
  useKittyForNeovim = profileName != "terminal" && programEnabled "neovim" && programEnabled "kitty";
  directoryMimeHandlers = lib.toList (config.xdg.mime.defaultApplications."inode/directory" or [ ]);
  fileMimeHandlers = lib.genAttrs [
    "text/plain" "text/markdown" "text/x-markdown" "application/x-zerosize"
    "text/x-lua" "text/x-python" "application/json" "application/x-shellscript"
  ] (mime: lib.filter (name: name != "") (lib.splitString ";" (config.xdg.mime.defaultApplications.${mime} or "nvim.desktop")));
  # Mirrors *.desktop files Steam (and similar launchers) drop into
  # ~/Desktop over to ~/.local/share/applications so dock/launcher icons
  # actually see them. Run both at HM activation and via a systemd --user
  # path unit that reacts to ~/Desktop changes at runtime.
  syncDesktopShortcutsScript = pkgs.writeShellScript "sync-desktop-shortcuts" ''
    set -euo pipefail
    src="$HOME/Desktop"
    dst="$HOME/.local/share/applications"
    [ -d "$src" ] || exit 0
    mkdir -p "$dst"
    shopt -s nullglob
    for f in "$src"/*.desktop; do
      cp -f "$f" "$dst/$(basename "$f")"
    done
    ${pkgs.desktop-file-utils}/bin/update-desktop-database "$dst" 2>/dev/null || true
  '';

  # Python env for ~/.config/openrgb/lg213/main.py (notification RGB effects)
  lg213PythonEnv = pkgs.python3.withPackages (ps: [ ps.openrgb-python ]);


in {
  options.orgm.dotfiles.repository = lib.mkOption {
    type = lib.types.str;
    default = "/home/${userName}/Hobby/nixos";
    description = "Mutable checkout used by orgm-dot; never imported into the Nix store.";
  };
  config = {
    environment.systemPackages = [ dotPackage ] ++ lib.optionals (programEnabled "tmux") [
      pkgs.tmuxPlugins.resurrect pkgs.tmuxPlugins.continuum
    ];
    environment.etc."orgm-dot/context.json".text = contextJSON;
    systemd.services.display-manager = {
      after = [ "home-manager-${userName}.service" ];
      wants = [ "home-manager-${userName}.service" ];
    };
    home-manager.users.${userName} = { config, lib, pkgs, ... }: {
      # Terminal=true lets GIO choose its own terminal (often xterm), ignoring
      # TERMINAL and xdg-terminal-exec. Launch Kitty explicitly for Neovim.
      xdg.desktopEntries.nvim = lib.mkIf useKittyForNeovim {
        name = "Neovim";
        genericName = "Text Editor";
        exec = "${pkgs.kitty}/bin/kitty -e nvim %F";
        icon = "nvim";
        terminal = false;
        categories = [ "Utility" "TextEditor" "Development" ];
        mimeType = [ "text/plain" "text/x-lua" "text/x-python" "application/json" "application/x-shellscript" ];
      };
      xdg.dataFile."applications/nvim.desktop" = lib.mkIf useKittyForNeovim {
        source = "${builtins.head (builtins.filter (p: p.name == "nvim.desktop") config.home.packages)}/share/applications/nvim.desktop";
      };
      xdg.configFile = lib.mkMerge [
        (lib.optionalAttrs (programEnabled "tailscale" && !ryokuEnabled && hostName != "envy" && !retireOrgmTrays) {
          # GNOME and Cinnamon launch this in the light variant. i3, Hyprland,
          # and Labwc start the same command explicitly.
          "autostart/tailscale-systray.desktop".text = ''
            [Desktop Entry]
            Type=Application
            Name=Tailscale
            Comment=Manage Tailscale from the system tray
            Exec=tailscale systray --theme light
            Terminal=false
            X-GNOME-Autostart-enabled=true
            OnlyShowIn=GNOME;X-Cinnamon;
          '';
        })
        (lib.optionalAttrs (programEnabled "syncthing" && !ryokuEnabled && hostName != "envy" && !retireOrgmTrays) {
          # The setup wizard can create this file before Home Manager owns it.
          # Replace only the autostart entry, not the user's syncthingtray.ini.
          "autostart/syncthingtray.desktop" = {
            force = true;
            text = ''
              [Desktop Entry]
              Type=Application
              Name=Syncthing Tray
              Comment=Manage Syncthing from the system tray
              Exec=syncthingtray --single-instance --wait
              Terminal=false
              X-GNOME-Autostart-enabled=true
              OnlyShowIn=GNOME;X-Cinnamon;
            '';
          };
        })
        (lib.optionalAttrs retireOrgmTrays (lib.genAttrs (map (name: "autostart/${name}") retiredTrayNames) (_: {
          force = true;
          text = "[Desktop Entry]\nType=Application\nHidden=true\n";
        })))
      ];

      # Archive existing launchers before Home Manager owns the two masks.
      # The small cleanup utility is shared with Ryoku; no Ryoku runtime is loaded.
      home.activation.orgmRetiredTrayBackups = lib.mkIf retireOrgmTrays (
        lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
          $DRY_RUN_CMD ${pkgs.python3}/bin/python3 ${./profiles/ryoku/cleanup.py} \
            "$HOME" "''${XDG_STATE_HOME:-$HOME/.local/state}/orgm-desktop" \
            ${retiredTrayManifest}
        ''
      );

      # Keep synchronization independent of the selected shell and tray.
      # Ryoku console modes and Envy's return to Hyprland retain the same unit.
      systemd.user.services.syncthing = lib.mkIf
        (programEnabled "syncthing" && (profileName == "ryoku" || hostName == "envy" || retireOrgmTrays))
        (import ./syncthing/user-service.nix { inherit pkgs; });

      # Keep user-level MIME preferences in sync with declarative defaults,
      # which take precedence over /etc/xdg/mimeapps.list.
      home.activation.setPreferredFileHandlers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        ${lib.optionalString (directoryMimeHandlers != [ ]) ''
          $DRY_RUN_CMD ${pkgs.xdg-utils}/bin/xdg-mime default ${lib.escapeShellArg (builtins.head directoryMimeHandlers)} inode/directory
        ''}
        ${lib.optionalString (profileName != "terminal") ''
          $DRY_RUN_CMD ${pkgs.xdg-utils}/bin/xdg-mime default chromium-browser.desktop text/html
          $DRY_RUN_CMD ${pkgs.xdg-utils}/bin/xdg-mime default chromium-browser.desktop application/xhtml+xml
          $DRY_RUN_CMD ${pkgs.xdg-utils}/bin/xdg-mime default firefox.desktop x-scheme-handler/http
          $DRY_RUN_CMD ${pkgs.xdg-utils}/bin/xdg-mime default firefox.desktop x-scheme-handler/https
        ''}
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (mime: handlers:
          lib.optionalString (handlers != [ ])
            "$DRY_RUN_CMD ${pkgs.xdg-utils}/bin/xdg-mime default ${lib.escapeShellArg (builtins.head handlers)} ${lib.escapeShellArg mime}"
        ) fileMimeHandlers)}
      '';


      # Run before old HM links are removed so backups retain their content.
      # Later activations are a no-op for already initialized applications.
      home.activation.orgmDotBootstrap = lib.hm.dag.entryBetween
        [ "linkGeneration" ] [ "writeBoundary" ] ''
          $DRY_RUN_CMD ${dotPackage}/bin/orgm-dot --context ${contextFile} bootstrap
        '';

      # Steam writes desktop launchers to ~/Desktop; no non-Steam user needs
      # the copy-on-change service.
      home.activation.syncDesktopShortcuts = lib.mkIf (programEnabled "steam") (
        lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          $DRY_RUN_CMD ${syncDesktopShortcutsScript}
        ''
      );

      # Keep lid-close inhibition alive when a graphical compositor exits while
      # an external display remains physically connected.
      systemd.user.services.external-lid-inhibit = lib.mkIf (programEnabled "shell" && profileName != "ryoku") {
        Unit.Description = "Block laptop lid suspend with an external display";
        Service = {
          ExecStart = "%h/.local/bin/external-lid-inhibit";
          Restart = "on-failure";
          RestartSec = 5;
        };
        Install.WantedBy = [ "default.target" ];
      };

      systemd.user.services.desktop-shortcut-sync = lib.mkIf (programEnabled "steam") {
        Unit.Description = "Copy *.desktop shortcuts from ~/Desktop into ~/.local/share/applications";
        Service = {
          Type = "oneshot";
          ExecStart = "${syncDesktopShortcutsScript}";
        };
      };

      # Lenovo has no G213; avoid starting a detector that can only exit.
      systemd.user.services.openrgb-notify = lib.mkIf (programEnabled "openrgb" && hostName != "lenovo" && !builtins.elem profileName [ "ryoku" "sway" ]) {
        Unit.Description = "Blink G213 keyboard zones on app notifications";
        Service = {
          ExecStart = "${lg213PythonEnv}/bin/python3 %h/.config/openrgb/lg213/main.py";
          Environment = [ "PATH=${pkgs.dbus}/bin:${pkgs.openrgb}/bin" ];
          Restart = "on-failure";
          RestartSec = 10;
        };
        Install.WantedBy = [ "default.target" ];
      };

      systemd.user.paths.desktop-shortcut-sync = lib.mkIf (programEnabled "steam") {
        Unit.Description = "Watch ~/Desktop for new .desktop shortcuts (e.g. from Steam)";
        Path.PathChanged = "%h/Desktop";
        Path.Unit = "desktop-shortcut-sync.service";
        Install.WantedBy = [ "default.target" ];
      };


      home.file =
        {
          ".local/bin/orgm-dot".source = "${dotPackage}/bin/orgm-dot";
          ".local/state/orgm-dot/runtime" = { source = "${dotPackage}"; force = true; };
          ".local/state/orgm-dot/context.json".text = contextJSON;
        }
        // lib.optionalAttrs (programEnabled "orgm") {
          ".local/bin/orgmai".source = "${orgmaiPackage}/bin/orgmai";
          ".local/bin/ai-chat".source = "${orgmaiPackage}/bin/ai-chat";
          # The user runtime can be activated without switching the whole OS.
          # Keep its live GC-root pointer on the same declared package thereafter.
          ".local/state/orgmai/runtime" = {
            source = "${orgmaiPackage}";
            force = true;
          };
        }
;
    };
  };
}
