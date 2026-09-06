{
  config,
  pkgs,
  lib,
  userName ? "osmarg",
  profileName ? "hyprland",
  ...
}:

let
  dotfilesRepo = "https://github.com/osmargm1202/nixos.git";
  dotfilesBranch = "master";
  dotfilesRepoPath = "/home/${userName}/Hobby/nixos";
  dotfilesPath = "/home/${userName}/Hobby/nixos/dotfiles";
  dotfilesParent = "/home/${userName}/Hobby";
  hostName = config.networking.hostName;
  directoryMimeHandlers = lib.toList (config.xdg.mime.defaultApplications."inode/directory" or [ ]);

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

  migrateHomeManagerDotfileDirs = pkgs.writeShellApplication {
    name = "migrate-home-manager-dotfile-dirs";
    runtimeInputs = [ pkgs.coreutils ];
    text = builtins.readFile ./scripts/migrate-home-manager-dotfile-dirs.sh;
  };

  # Python env for ~/.config/openrgb/lg213/main.py (notification RGB effects)
  lg213PythonEnv = pkgs.python3.withPackages (ps: [ ps.openrgb-python ]);

  orgmDotfilesUpdateScript = pkgs.writeShellApplication {
    name = "orgm-dotfiles-update";
    runtimeInputs = with pkgs; [
      git
      openssh
    ];
    text = ''
      cd "${dotfilesRepoPath}"
      git fetch origin "${dotfilesBranch}"
      git checkout "${dotfilesBranch}"
      git pull --ff-only origin "${dotfilesBranch}" || true
    '';
  };

  # Inventory uses the evaluated source tree; links retain the mutable checkout.
  collectLayerFiles =
    {
      inventoryRoot,
      runtimeRoot,
      prefix ? "",
    }:
    if !builtins.pathExists inventoryRoot then
      { }
    else
      lib.foldlAttrs (
        files: name: type:
        let
          target = prefix + name;
          metadata =
            builtins.elem name [
              ".git"
              ".gitignore"
              ".DS_Store"
              "icon-theme.cache"
              "mimeinfo.cache"
            ]
            || builtins.match "Icon." name != null
            || lib.hasSuffix "~" name
            || lib.hasSuffix ".bak" name;
        in
        if metadata then
          files
        else if type == "directory" then
          files
          // collectLayerFiles {
            inventoryRoot = "${inventoryRoot}/${name}";
            runtimeRoot = "${runtimeRoot}/${name}";
            prefix = "${target}/";
          }
        else if type == "regular" || type == "symlink" then
          files // { ${target} = "${runtimeRoot}/${name}"; }
        else
          files
      ) { } (builtins.readDir inventoryRoot);

  layerFiles =
    layer:
    collectLayerFiles {
      inventoryRoot = "${toString ../dotfiles/config}/${layer}";
      runtimeRoot = "${dotfilesPath}/config/${layer}";
    };
  sharedFiles = layerFiles "shared";
  hyprlandFiles = layerFiles "profiles/hyprland";
  persistentHyprlandFiles =
    lib.filterAttrs (
      path: _:
      lib.hasPrefix ".config/hypr/" path
      || lib.hasPrefix ".config/orgm-hypr/" path
      || lib.hasPrefix ".config/waybar-hypr/" path
      || lib.hasPrefix ".local/bin/hypr-" path
      || lib.hasPrefix ".local/bin/waybar-" path
    ) hyprlandFiles
    // builtins.listToAttrs (
      map (file: {
        name = file.target;
        value = "${dotfilesPath}/config/profiles/hyprland/${file.source}";
      }) persistentHyprlandRofiFiles
    );
  # Keep the Rofi theme required by Hyprland helpers separate from the active
  # profile's general Rofi configuration, which i3 owns at ~/.config/rofi.
  persistentHyprlandRofiFiles = [
    {
      target = ".config/orgm-hypr/rofi/hypr-menu.rasi";
      source = ".config/rofi/hypr-menu.rasi";
    }
    {
      target = ".config/orgm-hypr/rofi/hypr-menu.env";
      source = ".config/rofi/hypr-menu.env";
    }
    {
      target = ".config/orgm-hypr/rofi/orgm-current.rasi";
      source = ".config/rofi/orgm-current.rasi";
    }
  ];
  profileFiles = layerFiles "profiles/${profileName}";
  hostFiles = layerFiles "hosts/${hostName}/shared";
  hostProfileFiles = layerFiles "hosts/${hostName}/profiles/${profileName}";
  mergedFiles =
    sharedFiles // persistentHyprlandFiles // profileFiles // hostFiles // hostProfileFiles;
  # Nautilus requires a real executable, installed by its activation below.
  linkedFiles = builtins.removeAttrs mergedFiles [
    ".local/share/nautilus/scripts/Set as Hyprland Wallpaper"
  ];
  # Unlink legacy directory-level HM links before touching any managed leaf.
  # Otherwise removing a leaf through an old parent link deletes its source.
  managedDirectories = lib.sort builtins.lessThan (
    lib.unique (
      lib.concatMap (
        path:
        let
          parts = lib.splitString "/" path;
        in
        lib.genList (index: lib.concatStringsSep "/" (lib.take (index + 1) parts)) (
          builtins.length parts - 1
        )
      ) (builtins.attrNames linkedFiles)
    )
  );
in
{
  systemd.tmpfiles.rules = [
    "d ${dotfilesParent} 0755 ${userName} users - -"
  ];

  # Ensure the graphical login starts only after home-manager has finished
  # linking the dotfiles. Without this ordering the compositor can read its
  # configuration before the Lua symlinks exist and enter emergency mode.
  # `wants` (not `requires`) so a home-manager failure degrades gracefully
  # instead of blocking login entirely.
  systemd.services.display-manager = {
    after = [ "home-manager-${userName}.service" ];
    wants = [ "home-manager-${userName}.service" ];
  };

  # Boot only needs the repo to *exist* — home-manager reads from disk, it
  # doesn't need today's remote commits. This used to also `git fetch` on
  # every boot gated on network-online.target, serializing ~5-6s of
  # NetworkManager-wait-online + the fetch itself in front of home-manager
  # and login. Now it's a no-op (no network touched) once cloned once.
  systemd.services.orgm-dotfiles-repo = {
    description = "Ensure ORGM dotfiles repository is cloned";
    before = [ "home-manager-${userName}.service" ];
    wantedBy = [ "multi-user.target" ];
    path = with pkgs; [
      bash
      coreutils
      git
      gnugrep
      openssh
      util-linux
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -euo pipefail

      install -d -m 0755 -o ${userName} -g users "${dotfilesParent}"

      as_user() {
        runuser -u ${userName} -- "$@"
      }

      if [ ! -e "${dotfilesRepoPath}/.git" ]; then
        if [ -e "${dotfilesRepoPath}" ]; then
          echo "${dotfilesRepoPath} exists but is not a git repository" >&2
          exit 1
        fi
        as_user git clone --branch "${dotfilesBranch}" "${dotfilesRepo}" "${dotfilesRepoPath}"
        chown -R ${userName}:users "${dotfilesRepoPath}"
      fi
    '';
  };

  # Pulling latest dotfiles is now decoupled from boot entirely: a manual CLI
  # helper (orgm-dotfiles-update) plus a background timer that starts well
  # after login and re-runs daily. Neither blocks boot or home-manager.
  systemd.services.orgm-dotfiles-update = {
    description = "Fetch latest ORGM dotfiles (non-blocking)";
    after = [
      "network-online.target"
      "orgm-dotfiles-repo.service"
    ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = userName;
      ExecStart = "${orgmDotfilesUpdateScript}/bin/orgm-dotfiles-update";
    };
  };

  systemd.timers.orgm-dotfiles-update = {
    description = "Periodic ORGM dotfiles update";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "1d";
      Persistent = true;
    };
  };

  home-manager.users.${userName} =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      home.activation.migrateLegacyDotfileDirectories =
        lib.hm.dag.entryBefore [ "removeConflictingDotfiles" ]
          ''
            $DRY_RUN_CMD ${migrateHomeManagerDotfileDirs}/bin/migrate-home-manager-dotfile-dirs \
              ${lib.escapeShellArgs (
                lib.sort builtins.lessThan (
                  lib.unique (
                    [
                      ".config/kitty"
                      ".config/yazi"
                    ]
                    ++ managedDirectories
                  )
                )
              )}
          '';
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
        for mime in \
          text/plain \
          text/markdown \
          text/x-markdown \
          text/x-lua \
          text/x-python \
          application/json \
          application/x-shellscript; do
          $DRY_RUN_CMD ${pkgs.xdg-utils}/bin/xdg-mime default nvim.desktop "$mime"
        done
      '';

      home.activation.removeConflictingDotfiles = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
        if [ -L "$HOME/.local/share/applications" ]; then
          $DRY_RUN_CMD rm "$HOME/.local/share/applications"
        fi

        for old_dir in \
          .config/hypr \
          .config/orgm-hypr \
          .config/waybar .config/waybar-hypr \
          .config/nwg-dock-hyprland \
          .config/qt5ct .config/qt6ct \
          .config/quickshell .config/gtk-4.0 \
          .config/Kvantum \
          .config/i3 .config/picom \
          .config/labwc \
          .config/conky \
          .icons \
          .local/share/icons; do
          target="$HOME/$old_dir"
          if [ -L "$target" ]; then
            $DRY_RUN_CMD rm "$target"
          fi
        done

        declare -a managed_paths=(
          ${lib.concatMapStringsSep "\n          " (p: ''"${p}"'') (builtins.attrNames linkedFiles)}
        )
        for p in "''${managed_paths[@]}"; do
          target="$HOME/$p"
          if [ -e "$target" ] || [ -L "$target" ]; then
            $DRY_RUN_CMD rm -rf "$target"
          fi
        done
      '';

      home.activation.initGeneratedConfigs = lib.hm.dag.entryAfter [ "linkGeneration" ] (
        ''
          init_file() {
            local dst="$HOME/$1" content="''${2:-}"
            [ -e "$dst" ] && return 0
            $DRY_RUN_CMD mkdir -p "$(dirname "$dst")"
            $DRY_RUN_CMD bash -c "printf '%s' '$content' > '$dst'"
          }
          init_file ".config/kitty/current-theme.conf" "# generated by orgm-themes"
        ''
        + lib.optionalString (profileName == "hyprland") ''
                    init_file ".config/gtk-3.0/settings.ini" "[Settings]
          gtk-theme-name=Adwaita
          gtk-application-prefer-dark-theme=true
          gtk-icon-theme-name=Colloid-Dark
          gtk-cursor-theme-name=Catppuccin-Macchiato-Teal-Cursors
          gtk-cursor-theme-size=36
          gtk-font-name=Inter 11
          gtk-xft-antialias=1
          gtk-xft-hinting=1
          gtk-xft-hintstyle=hintslight
          gtk-xft-rgba=none
          gtk-overlay-scrolling=true
          "
                    init_file ".config/gtk-4.0/settings.ini" "[Settings]
          gtk-theme-name=Adwaita
          gtk-application-prefer-dark-theme=true
          gtk-icon-theme-name=Colloid-Dark
          gtk-cursor-theme-name=Catppuccin-Macchiato-Teal-Cursors
          gtk-cursor-theme-size=36
          gtk-font-name=Inter 11
          gtk-xft-antialias=1
          gtk-xft-hinting=1
          gtk-xft-hintstyle=hintslight
          gtk-xft-rgba=none
          gtk-overlay-scrolling=true
          "
                    init_file ".icons/default/index.theme" "[Icon Theme]
          Name=Default
          Comment=Default Cursor Theme
          Inherits=Catppuccin-Macchiato-Teal-Cursors
          "
                    init_file ".local/state/hypr/game-mode" "deactivated"
                    init_file ".config/waybar/orgm-current.css"            "/* generated by orgm-themes */"
                    init_file ".config/waybar-hypr/orgm-current.css"       "/* generated by orgm-themes */"
                    init_file ".config/rofi/orgm-current.rasi"             "/* generated by orgm-themes */"
                    init_file ".config/nwg-dock-hyprland/orgm-current.css" "/* generated by orgm-themes */"
                    init_file ".config/qt5ct/qt5ct.conf"     ""
                    init_file ".config/qt5ct/colors/orgm-current.colors" ""
                    init_file ".config/qt6ct/qt6ct.conf"     ""
                    init_file ".config/qt6ct/colors/orgm-current.colors" ""
                    init_file ".config/Kvantum/kvantum.kvconfig" ""
                    init_file ".config/kdeglobals"            ""
                    init_file ".config/hypr/scheme/current.conf" "# generated by orgm-themes"

                    init_file ".local/state/orgm-theme/current"     "orgm-dark"
                    init_file ".local/state/orgm-theme/current.env" ""
                    init_file ".config/vesktop/settings/quickcss.css" "/* generated by orgm-themes */"
        ''
      );

      # Nautilus 50 does not discover symlinked scripts. Keep the Hyprland
      # action as a real executable file; i3 deliberately gets no Nautilus
      # script.
      home.activation.installHyprlandNautilusScript = lib.hm.dag.entryAfter [ "linkGeneration" ] (
        lib.optionalString (profileName == "hyprland") ''
          $DRY_RUN_CMD rm -f "$HOME/.local/share/nautilus/scripts/Set as Hyprland Wallpaper"
          $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -Dm755 \
            "${dotfilesPath}/config/profiles/hyprland/.local/share/nautilus/scripts/Set as Hyprland Wallpaper" \
            "$HOME/.local/share/nautilus/scripts/Set as Hyprland Wallpaper"
        ''
      );

      # Home Manager replaces the i3 config symlink during a live switch.
      # Reload through IPC afterward so i3 re-establishes its keyboard grabs.
      home.activation.reloadI3AfterLink = lib.hm.dag.entryAfter [ "linkGeneration" ] (
        lib.optionalString (profileName == "i3") ''
          $DRY_RUN_CMD "$HOME/.local/bin/i3-reload-after-switch" || true
        ''
      );

      # A NixOS/Home Manager switch replaces the Hyprland config symlink.
      # Reload the live compositor and restart Waybar through its session IPC.
      home.activation.reloadHyprlandAfterLink = lib.hm.dag.entryAfter [ "linkGeneration" ] (
        lib.optionalString (profileName == "hyprland") ''
          $DRY_RUN_CMD "$HOME/.local/bin/hypr-reload-after-switch" || true
        ''
      );

      # Steam (and similar launchers) write "Create desktop shortcut" .desktop
      # files into ~/Desktop instead of ~/.local/share/applications, so dock
      # and app-launcher icons never pick them up. Mirror them automatically.
      home.activation.syncDesktopShortcuts = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        $DRY_RUN_CMD ${syncDesktopShortcutsScript}
      '';

      # Keep lid-close inhibition alive when a graphical compositor exits while
      # an external display remains physically connected.
      systemd.user.services.external-lid-inhibit = {
        Unit.Description = "Block laptop lid suspend with an external display";
        Service = {
          ExecStart = "%h/.local/bin/external-lid-inhibit";
          Restart = "on-failure";
          RestartSec = 5;
        };
        Install.WantedBy = [ "default.target" ];
      };

      systemd.user.services.desktop-shortcut-sync = {
        Unit.Description = "Copy *.desktop shortcuts from ~/Desktop into ~/.local/share/applications";
        Service = {
          Type = "oneshot";
          ExecStart = "${syncDesktopShortcutsScript}";
        };
      };

      # Lenovo has no G213; avoid starting a detector that can only exit.
      systemd.user.services.openrgb-notify = lib.mkIf (hostName != "lenovo") {
        Unit.Description = "Blink G213 keyboard zones on app notifications";
        Service = {
          ExecStart = "${lg213PythonEnv}/bin/python3 %h/.config/openrgb/lg213/main.py";
          Environment = [ "PATH=${pkgs.dbus}/bin:${pkgs.openrgb}/bin" ];
          Restart = "on-failure";
          RestartSec = 10;
        };
        Install.WantedBy = [ "default.target" ];
      };

      systemd.user.paths.desktop-shortcut-sync = {
        Unit.Description = "Watch ~/Desktop for new .desktop shortcuts (e.g. from Steam)";
        Path.PathChanged = "%h/Desktop";
        Path.Unit = "desktop-shortcut-sync.service";
        Install.WantedBy = [ "default.target" ];
      };

      home.file = lib.mkMerge [
        (lib.mapAttrs (_: source: {
          source = config.lib.file.mkOutOfStoreSymlink source;
        }) linkedFiles)
        # tmux plugins are store-backed, so a fresh Home Manager activation
        # recreates them without TPM or mutable clones under ~/.tmux/plugins.
        {
          ".config/tmux/plugins.conf" = {
            force = true;
            text = ''
              run-shell ${pkgs.tmuxPlugins.resurrect}/share/tmux-plugins/resurrect/resurrect.tmux
              run-shell ${pkgs.tmuxPlugins.continuum}/share/tmux-plugins/continuum/continuum.tmux
            '';
          };
        }
      ];
    };

  environment.systemPackages = [ orgmDotfilesUpdateScript ];

}
