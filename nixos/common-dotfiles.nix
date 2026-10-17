{
  config,
  pkgs,
  lib,
  userName ? "osmarg",
  profileName ? "hyprland",
  ...
}:

let
  dotfileSource = import ../lib/dotfile-source.nix;
  sourceRoot = dotfileSource.source ../dotfiles/config;
  hostName = config.networking.hostName;
  ryokuEnabled = profileName == "ryoku" && (config.programs.ryoku.enable or false);
  programs = config.orgm.user.programs or [ ];
  programEnabled = name: builtins.elem name programs;
  useKittyForNeovim = profileName != "terminal" && programEnabled "neovim" && programEnabled "kitty";
  directoryMimeHandlers = lib.toList (config.xdg.mime.defaultApplications."inode/directory" or [ ]);
  fileMimeHandlers = lib.genAttrs [
    "text/plain" "text/markdown" "text/x-markdown" "application/x-zerosize"
    "text/x-lua" "text/x-python" "application/json" "application/x-shellscript"
  ] (mime: lib.toList (config.xdg.mime.defaultApplications.${mime} or [ "nvim.desktop" ]));

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

  # Every source path starts as a Nix path. Home Manager therefore links its
  # immutable store copy, never a file from a mutable checkout.
  collectLayerFiles =
    {
      root,
      prefix ? "",
    }:
    if !builtins.pathExists root then
      { }
    else
      lib.foldlAttrs (
        files: name: type:
        let
          target = prefix + name;
          metadata = dotfileSource.isMetadata name;
        in
        if metadata then
          files
        else if type == "directory" then
          files
          // collectLayerFiles {
            root = "${root}/${name}";
            prefix = "${target}/";
          }
        else if type == "regular" || type == "symlink" then
          files // { ${target} = "${root}/${name}"; }
        else
          files
      ) { } (builtins.readDir root);

  layerFiles = layer: collectLayerFiles { root = "${sourceRoot}/${layer}"; };
  layerNames =
    layer:
    let
      root = "${sourceRoot}/${layer}";
    in
    if builtins.pathExists root then builtins.attrNames (builtins.readDir root) else [ ];
  allProgramNames = lib.unique (
    layerNames "programs" ++ layerNames "users/${userName}/programs"
  );
  programFiles = lib.foldl' (
    files: program: files // layerFiles "programs/${program}"
  ) { } programs;
  profileFiles = layerFiles "profiles/${profileName}";
  userFiles = layerFiles "users/${userName}/common";
  userProgramFiles = lib.foldl' (
    files: program: files // layerFiles "users/${userName}/programs/${program}"
  ) { } programs;
  userProfileFiles = layerFiles "users/${userName}/profiles/${profileName}";
  hostFiles = layerFiles "hosts/${hostName}/shared";
  hostProfileFiles = layerFiles "hosts/${hostName}/profiles/${profileName}";
  selectedFiles =
    programFiles // profileFiles // userFiles // userProgramFiles // userProfileFiles // hostFiles // hostProfileFiles;
  # Ryoku materializes writable application configurations from its generation.
  # Keep personal tools available while giving each config path a single owner.
  ryokuConfigRoots = [
    ".config/hypr" ".config/niri" ".config/quickshell" ".config/matugen"
    ".config/qt6ct" ".config/gtk-3.0" ".config/gtk-4.0" ".config/btop"
    ".config/starship.toml" ".config/fastfetch" ".config/kitty" ".config/fish"
    ".config/wireplumber" ".config/yazi" ".config/nvim" ".config/pip"
    ".config/chromium-flags.conf" ".config/hyprland-preview-share-picker"
  ];
  # Register destination-to-source directory mappings, not arbitrary Store roots.
  legacyDirectoryTargets = [
    ".config/hypr" ".config/niri" ".config/orgm-hypr" ".config/waybar" ".config/waybar-hypr"
    ".config/nwg-dock-hyprland" ".config/qt5ct" ".config/qt6ct" ".config/quickshell"
    ".config/gtk-4.0" ".config/Kvantum" ".config/i3" ".config/picom"
    ".config/labwc" ".config/conky" ".icons" ".local/share/icons"
  ];
  legacyDirectoryLayers = [ "shared" "users/${userName}/common" "hosts/${hostName}/shared" ]
    ++ map (p: "profiles/${p}") (layerNames "profiles")
    ++ map (p: "users/${userName}/profiles/${p}") (layerNames "users/${userName}/profiles")
    ++ map (p: "hosts/${hostName}/profiles/${p}") (layerNames "hosts/${hostName}/profiles")
    ++ map (p: "programs/${p}") programs
    ++ map (p: "users/${userName}/programs/${p}") programs;
  legacyDirectoryManifest = pkgs.writeText "ryoku-legacy-directory-sources.json" (builtins.toJSON
    (map (target: {
      inherit target;
      sources = builtins.filter builtins.pathExists (map
        (layer: "${sourceRoot}/${layer}/${target}") legacyDirectoryLayers);
      blocksNative = builtins.elem target ryokuConfigRoots;
    }) legacyDirectoryTargets));
  ryokuOwns = path: builtins.any (
    root: path == root || lib.hasPrefix (root + "/") path
  ) ryokuConfigRoots;
  ryokuShellPreference = path: path == ".bashrc" || path == ".blerc" || lib.hasPrefix ".config/bash/" path;
  ryokuCodePreference = path: lib.hasPrefix ".config/orgm-ryoku/" path
    && (lib.hasSuffix ".lua" path || lib.hasSuffix ".rasi" path);
  ryokuAppSeed = path: path == ".config/starship.toml" || builtins.any
    (root: lib.hasPrefix (root + "/") path) [ ".config/fastfetch" ".config/nvim" ".config/btop" ];
  ryokuEditable = path: ryokuShellPreference path || ryokuCodePreference path || ryokuOwns path;
  # Preference templates remain in the generation, but their active targets do
  # not remain Home Manager links. Match old source suffixes across generations.
  preferenceFiles = lib.filterAttrs (path: _: ryokuAppSeed path || ryokuCodePreference path) selectedFiles;
  oldShellFiles = lib.filterAttrs (path: _: lib.hasPrefix ".config/bash/" path) selectedFiles;
  seedRecord = target: source: {
    inherit target source;
    legacySources = lib.optional (builtins.hasAttr target selectedFiles) selectedFiles.${target};
  };
  seedRecords = lib.mapAttrsToList seedRecord preferenceFiles
    ++ lib.mapAttrsToList (target: source: (seedRecord target source) // { seed = false; }) oldShellFiles
    ++ [
      ((seedRecord ".bashrc" ./profiles/ryoku/bashrc) // { replaceLegacy = true; })
      ((seedRecord ".blerc" ./profiles/ryoku/blerc) // { replaceLegacy = true; })
      (seedRecord ".config/bash/user.bash" ./profiles/ryoku/bash-user.bash)
      (seedRecord ".config/kitty/user.conf" ./profiles/ryoku/kitty-user.conf)
    ];
  seedManifest = pkgs.writeText "ryoku-first-seed-manifest.json" (builtins.toJSON seedRecords);
  importLibraryFiles = lib.filterAttrs (path: _: builtins.elem (builtins.baseNameOf path)
    [ "functions.bash" "completions.bash" "sops-age.bash" "host-${hostName}.bash" ]) oldShellFiles;
  importLibraries = lib.mapAttrs' (path: source: lib.nameValuePair
    (".config/orgm-shell/" + builtins.baseNameOf path) { inherit source; }) importLibraryFiles;
  # A common user directory must not pull another desktop's controls into
  # Ryoku. Keep only workflows for which Ryoku has no equivalent; its native
  # shell owns capture, history, night light, network menus and status widgets.
  ryokuSharedUserHelpers = [
    "bookmark_add" "bookmark_delete" "bookmark_to_type" "clipboard_copy"
    "hypr-video-timer"
  ];
  mergedFiles = lib.filterAttrs (
    path: source: profileName != "ryoku" || (
      !ryokuOwns path
      && !(ryokuEnabled && (ryokuShellPreference path || ryokuCodePreference path))
      && !(lib.hasPrefix ".local/bin/" path
        && source == (userFiles.${path} or null)
        && !builtins.elem (builtins.baseNameOf path) ryokuSharedUserHelpers)
      && !builtins.elem path [
        ".local/bin/orgm-visual-profile" ".local/bin/openrgb-autostart" ".local/bin/dunst_pause"
      ]
    )
  ) selectedFiles;
  allProgramFiles = lib.foldl' (
    files: program:
    files
    // layerFiles "programs/${program}"
    // layerFiles "users/${userName}/programs/${program}"
  ) { } allProgramNames;
  disabledProgramFiles = lib.filterAttrs (path: _: !builtins.hasAttr path mergedFiles
    && !(ryokuEnabled && ryokuEditable path)) allProgramFiles;
  nautilusWallpaperScript =
    mergedFiles.".local/share/nautilus/scripts/Set as Hyprland Wallpaper" or null;
  hyprReloadHelper = mergedFiles.".local/bin/hypr-reload-after-switch" or null;
  hasHyprVisualProfile = builtins.hasAttr ".local/bin/orgm-visual-profile" mergedFiles;
  # These are runtime outputs. Their immutable defaults are installed as real
  # files below so theme helpers can atomically replace them.
  linkedFiles = builtins.removeAttrs mergedFiles [
    ".config/waybar-hypr/orgm-current.css"
    ".config/nwg-dock-hyprland/current-theme.css"
    ".config/kitty/current-theme.conf"
    ".config/gtk-3.0/settings.ini"
    ".config/gtk-4.0/settings.ini"
    ".local/share/nautilus/scripts/Set as Hyprland Wallpaper"
  ];
in
{

  # Ensure the graphical login starts only after home-manager has finished
  # linking the dotfiles. Without this ordering the compositor can read its
  # configuration before the Lua symlinks exist and enter emergency mode.
  # `wants` (not `requires`) so a home-manager failure degrades gracefully
  # instead of blocking login entirely.
  systemd.services.display-manager = {
    after = [ "home-manager-${userName}.service" ];
    wants = [ "home-manager-${userName}.service" ];
  };


  home-manager.users.${userName} =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
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
        (lib.optionalAttrs ryokuEnabled {
          "orgm-ryoku/seed.py".source = ./profiles/ryoku/seed.py;
          "orgm-ryoku/seed-manifest.json".text = builtins.toJSON seedRecords;
        })
        (lib.optionalAttrs (programEnabled "tailscale" && !ryokuEnabled) {
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
        (lib.optionalAttrs (programEnabled "syncthing" && !ryokuEnabled) {
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
      ];

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

      home.activation.ryokuFirstSeed = lib.mkIf ryokuEnabled (lib.hm.dag.entryBefore
        [ "removeConflictingDotfiles" "checkLinkTargets" ] ''
          $DRY_RUN_CMD ${pkgs.python3}/bin/python3 ${./profiles/ryoku/seed.py} \
            "''${XDG_CONFIG_HOME:-$HOME/.config}" "''${XDG_STATE_HOME:-$HOME/.local/state}/orgm-ryoku" \
            "$HOME" ${seedManifest}
        '');

      home.activation.removeConflictingDotfiles = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
        ${lib.optionalString (!ryokuEnabled) ''
          # Returning from Ryoku: save writable materialized files that the
          # selected profile will replace with generation-owned links.
          ryoku_state="''${XDG_STATE_HOME:-$HOME/.local/state}/orgm-ryoku"
          if [ -f "$ryoku_state/active" ]; then
            backup="$ryoku_state/return-$(date +%Y%m%d-%H%M%S)-$$"
            $DRY_RUN_CMD mkdir -p -m0700 "$backup"
            $DRY_RUN_CMD cp ${pkgs.writeText "ryoku-return-sources.json" (builtins.toJSON
              (lib.genAttrs (builtins.attrNames linkedFiles)
                (path: toString config.home.file.${path}.source)))} "$backup/replacement-sources.json"
            for p in ${lib.concatMapStringsSep " " lib.escapeShellArg (builtins.filter
              (path: ryokuOwns path || ryokuShellPreference path || ryokuCodePreference path)
              (builtins.attrNames linkedFiles))}; do
              target="$HOME/$p"
              case "$p" in .config/*|.bashrc|.blerc) ;; *) continue ;; esac
              if [ -f "$target" ] && [ ! -L "$target" ]; then
                $DRY_RUN_CMD mkdir -p "$backup/$(dirname "$p")"
                $DRY_RUN_CMD mv "$target" "$backup/$p"
              fi
            done
            # Keep user.conf and its editable opacity include untouched.
            # Other profiles use their own Kitty base (without that include).
            $DRY_RUN_CMD ${pkgs.bash}/bin/bash -c '
              umask 077
              tmp=$(mktemp "$2.XXXXXX")
              printf "%s\n" "$1" > "$tmp"
              mv -f -- "$tmp" "$2"
            ' _ "$backup" "$ryoku_state/return-latest"
            $DRY_RUN_CMD rm "$ryoku_state/active"
          fi
        ''}
        if [ -L "$HOME/.local/share/applications" ]; then
          $DRY_RUN_CMD rm "$HOME/.local/share/applications"
        fi

        ${lib.optionalString ryokuEnabled ''
          $DRY_RUN_CMD ${pkgs.python3}/bin/python3 ${./profiles/ryoku/seed.py} --directories \
            "$HOME" "''${XDG_STATE_HOME:-$HOME/.local/state}/orgm-ryoku" ${legacyDirectoryManifest} || exit $?
        ''}

        for old_dir in \
          .config/hypr \
          ${lib.optionalString ryokuEnabled ".config/niri"} \
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
            ${lib.optionalString ryokuEnabled "continue # Registered migration above owns Ryoku directory decisions."}
            $DRY_RUN_CMD rm "$target"
          fi
        done
        # Removing a selector is a clean cutover for Home Manager links only.
        # Never discard a regular file or directory a user may have created.
        declare -a disabled_program_paths=(
          ${lib.concatMapStringsSep "\n          " (p: ''"${p}"'') (builtins.attrNames disabledProgramFiles)}
        )
        for p in "''${disabled_program_paths[@]}"; do
          target="$HOME/$p"
          if [ -L "$target" ]; then
            $DRY_RUN_CMD rm "$target"
          fi
        done
        ${lib.optionalString (!programEnabled "tmux") ''
          plugin_loader="$HOME/.config/tmux/plugins.conf"
          if [ -L "$plugin_loader" ]; then
            $DRY_RUN_CMD rm "$plugin_loader"
          fi
          $DRY_RUN_CMD rmdir "$HOME/.config/tmux" 2>/dev/null || true
        ''}

        declare -a managed_paths=(
          ${lib.concatMapStringsSep "\n          " (p: ''"${p}"'') (builtins.attrNames linkedFiles)}
        )
        for p in "''${managed_paths[@]}"; do
          target="$HOME/$p"
          if [ -L "$target" ]; then
            $DRY_RUN_CMD rm "$target"
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
          init_runtime_file() {
            local dst="$HOME/$1"
            [ -L "$dst" ] && $DRY_RUN_CMD rm "$dst"
            init_file "$@"
          }
        ''
        + lib.optionalString (programEnabled "kitty" && profileName != "ryoku") ''
          init_runtime_file ".config/kitty/current-theme.conf" "background #080808
          foreground #f5f5f5
          selection_background #202020
          selection_foreground #f5f5f5
          cursor #8ab4f8
          "
        ''
        + lib.optionalString (profileName == "hyprland" && hasHyprVisualProfile) ''
          init_runtime_file ".config/waybar-hypr/orgm-current.css" "@define-color base #080808;
          @define-color mantle #101010;
          @define-color crust #000000;
          @define-color surface0 #202020;
          @define-color surface1 #303030;
          @define-color surface2 #424242;
          @define-color overlay0 #b8b8b8;
          @define-color overlay1 #d0d0d0;
          @define-color overlay2 #e3e3e3;
          @define-color text #f5f5f5;
          @define-color subtext0 #d0d0d0;
          @define-color subtext1 #e3e3e3;
          @define-color blue #8ab4f8;
          @define-color lavender #c4b5fd;
          @define-color sapphire #5d9cec;
          @define-color sky #67e8f9;
          @define-color teal #5eead4;
          @define-color green #8fd694;
          @define-color yellow #f8d477;
          @define-color peach #fdba74;
          @define-color maroon #fca5a5;
          @define-color red #ff8a8a;
          @define-color mauve #c4b5fd;
          @define-color pink #f9a8d4;
          @define-color flamingo #fbc4ab;
          @define-color rosewater #f5e0dc;
          @define-color panel_bg rgba(8, 8, 8, 0.94);
          @define-color panel_border #8ab4f8;
          "
          init_runtime_file ".config/nwg-dock-hyprland/current-theme.css" "#box { background: #080808; border: none; box-shadow: none; }
          "
          init_file ".icons/default/index.theme" "[Icon Theme]
          Name=Default
          Comment=Default Cursor Theme
          Inherits=Catppuccin-Macchiato-Teal-Cursors
          "
          init_file ".local/state/hypr/game-mode" "deactivated"
        ''
        + lib.optionalString hasHyprVisualProfile ''
          init_runtime_file ".config/dunst/dunstrc.d/90-visual-profile.conf" "[global]
              frame_width = 0
          [urgency_low]
              background = \"#101010\"
              foreground = \"#d0d0d0\"
          [urgency_normal]
              background = \"#080808\"
              foreground = \"#f5f5f5\"
          [urgency_critical]
              background = \"#202020\"
              foreground = \"#ff8a8a\"
          "
          init_runtime_file ".config/gtk-3.0/settings.ini" "[Settings]
          gtk-theme-name=Adwaita-dark
          gtk-icon-theme-name=Adwaita
          gtk-font-name=Sans 11
          gtk-application-prefer-dark-theme=1
          "
          init_runtime_file ".config/gtk-4.0/settings.ini" "[Settings]
          gtk-theme-name=Adwaita-dark
          gtk-icon-theme-name=Adwaita
          gtk-font-name=Sans 11
          gtk-application-prefer-dark-theme=1
          "
        ''
      );

      # Nautilus does not discover symlinked scripts. Install an executable
      # only when the selected layers deliberately provide the action.
      home.activation.installHyprlandNautilusScript = lib.mkIf (nautilusWallpaperScript != null) (
        lib.hm.dag.entryAfter [ "linkGeneration" ] ''
          $DRY_RUN_CMD rm -f "$HOME/.local/share/nautilus/scripts/Set as Hyprland Wallpaper"
          $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -Dm755 \
            "${nautilusWallpaperScript}" \
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

      # Reload only when the selected layers deliberately provide the helper.
      home.activation.reloadHyprlandAfterLink = lib.mkIf (hyprReloadHelper != null) (
        lib.hm.dag.entryAfter [ "linkGeneration" ] ''
          $DRY_RUN_CMD "$HOME/.local/bin/hypr-reload-after-switch" || true
        ''
      );

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
      systemd.user.services.openrgb-notify = lib.mkIf (programEnabled "openrgb" && hostName != "lenovo" && profileName != "ryoku") {
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
        (lib.mapAttrs (_: source: { inherit source; }) linkedFiles)
        // lib.optionalAttrs ryokuEnabled (importLibraries // {
          ".config/orgm-shell/workflows.bash".source = ./profiles/ryoku/bash-workflows.bash;
        })
        // lib.optionalAttrs (programEnabled "tmux") {
          # Plugins are supplied directly from the immutable Nix store; TPM
          # never needs a mutable clone under ~/.tmux/plugins.
          ".config/tmux/plugins.conf" = {
            force = true;
            text = ''
              run-shell ${pkgs.tmuxPlugins.resurrect}/share/tmux-plugins/resurrect/resurrect.tmux
              run-shell ${pkgs.tmuxPlugins.continuum}/share/tmux-plugins/continuum/continuum.tmux
            '';
          };
        };
    };


}
