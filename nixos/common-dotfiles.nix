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
  profileDotfilesName = profileName;

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

  # Paths symlinked for ALL profiles — terminal tools, editors, fonts, etc.
  # Source: dotfiles/config/shared/<path>
  sharedPaths = [
    ".config/bat"
    ".config/btop"
    ".config/delta"
    ".config/dolphinrc"
    ".config/fastfetch"
    # Bash is listed file-by-file so host-specific files can coexist with the
    # shared configuration without a directory-level symlink collision.
    ".bashrc"
    ".blerc"
    ".config/bash/config.bash"
    ".config/bash/completions.bash"
    ".config/bash/functions.bash"
    ".config/bash/sops-age.bash"
    ".config/bash/fzf-widgets.bash"
    ".config/bash/icons"
    ".config/helix"
    ".config/kitty/kitty.conf"
    ".config/clipcat"
    ".config/mpv"
    ".config/nvim"
    ".config/openrgb/lg213"
    ".config/orgm-hosts"
    ".config/posting"
    ".config/starship.toml"
    ".config/wallpapers"
    ".config/warp-terminal/settings.toml"
    ".config/zathura"
    ".config/zellij"
    # ".icons" intentionally NOT symlinked: nwg-look and dark/light theme
    # automation own it; the default cursor theme is seeded once below.
    ".local/bin/kbd-layout-next"
    ".local/bin/memclean-dev"
    ".local/bin/mic-volume-osd"
    ".local/bin/openrgb-autostart"
    ".local/bin/volume-osd"
    ".local/bin/brightness-osd"
    ".local/bin/reset_config"
    ".local/bin/steam-workshop-image"
    ".local/bin/windows-rdp"
    ".local/bin/aichat-rewrite"
    ".local/bin/airplane_mode_toggle"
    ".local/bin/archive-preview"
    ".local/bin/autostart"
    ".local/bin/bluetooth_toggle"
    ".local/bin/bookmark_add"
    ".local/bin/bookmark_delete"
    ".local/bin/bookmark_to_type"
    ".local/bin/check_airplane_mode"
    ".local/bin/check_geo_module"
    ".local/bin/check_night_mode"
    ".local/bin/check_recording"
    ".local/bin/check_webcam"
    ".local/bin/clear-op"
    ".local/bin/clipboard_clear"
    ".local/bin/clipboard_copy"
    ".local/bin/clipboard_delete_item"
    ".local/bin/clipboard_to_type"
    ".local/bin/clipboard_to_wlcopy"
    ".local/bin/claude"
    ".local/bin/codex"
    ".local/bin/dir-preview"
    ".local/bin/dunst_pause"
    ".local/bin/fetch_music_player_data"
    ".local/bin/file-preview"
    ".local/bin/flakeinit"
    ".local/bin/firefox-open-tab"
    ".local/bin/image-preview"
    ".local/bin/kitty_launch"
    ".local/bin/list-op"
    ".local/bin/night_mode_temp_down"
    ".local/bin/night_mode_temp_up"
    ".local/bin/night_mode_toggle"
    ".local/bin/nixclean"
    ".local/bin/sops-shared-env"
    ".local/bin/record_screen_gif"
    ".local/bin/record_screen_mp4"
    ".local/bin/screenshot_edit"
    ".local/bin/screenshot_to_clipboard"
    ".local/bin/sshgo"
    ".local/bin/tmux-spanish-date"
    ".local/bin/switch-preview"
    ".local/bin/unbindheadset"
    ".local/bin/wifi_toggle"
    ".local/bin/wlogout_uniqe"
    ".local/share/icons/hicolor/256x256/apps"
    ".local/share/applications/windows-rdp.desktop"
    ".local/share/applications/windows-web-console.desktop"
    ".local/share/icons/nixos.svg"
    ".local/share/icons/windows.png"
    ".local/share/posting"
    ".local/share/themes"
    ".pi/agent/AGENTS.md"
    ".pi/agent/RTK.md"
    ".pi/agent/ask.jsonc"
    ".pi/agent/models.json"
    ".pi/agent/subagents"
    ".pi/agent/subagents.json"
    ".tmux.conf"
  ];

  # Profile-specific paths — only symlinked when matching profile is active.
  # Source: dotfiles/config/profiles/<profile>/<path>.
  profileSpecificPaths = {
    hyprland = [
      ".config/dunst"
      ".config/nwg-dock-hyprland"
      ".config/hypr/hypridle.conf"
      ".config/hypr/hyprland.lua"
      ".config/hypr/hyprlock.conf"
      ".config/hypr/lua/autostart.lua"
      ".config/hypr/lua/environment.lua"
      ".config/hypr/lua/input.lua"
      ".config/hypr/lua/keybindings.lua"
      ".config/hypr/lua/layout.lua"
      ".config/hypr/lua/look-and-feel.lua"
      ".config/hypr/lua/monitors.lua"
      ".config/hypr/lua/permissions.lua"
      ".config/hypr/lua/programs.lua"
      ".config/hypr/lua/README.md"
      ".config/hypr/lua/windows-workspaces.lua"
      ".config/hypr/noctalia/noctalia-colors.conf"
      ".config/hypr/scripts/pi-walker-prompt.sh"
      ".config/hypr/scripts/walker-window-switch.sh"
      ".config/orgm-hypr/notify-focus.json"
      ".config/orgm-hypr/themes.json"
      ".config/orgm-theme"

      ".config/waybar-hypr"
      ".config/rofi"
      ".config/swappy"
      ".local/share/nautilus/scripts/Set as Hyprland Wallpaper"
      ".local/bin/hypr-apps-menu"
      ".local/bin/hypr-battery-alerts"
      ".local/bin/hypr-app-launcher"
      ".local/bin/hypr-config-editor"
      ".local/bin/hypr-current-wallpaper"
      ".local/bin/hypr-devices-menu"
      ".local/bin/hypr-display-targets"
      ".local/bin/hypr-help-menu"
      ".local/bin/hypr-keybindings-help"
      ".local/bin/hypr-keyhelper"
      ".local/bin/hypr-keyboard-menu"
      ".local/bin/hypr-kill-windows"
      ".local/bin/hypr-lock"
      ".local/bin/hypr-main-menu"
      ".local/bin/hypr-obsidian-open-or-focus"
      ".local/bin/hypr-nwg-dock"
      ".local/bin/hypr-nwg-dock-reload"
      ".local/bin/hypr-pi-prompt"
      ".local/bin/hypr-power-menu"
      ".local/bin/hypr-rofi-calc"
      ".local/bin/hypr-rofi-clipboard"
      ".local/bin/hypr-rofi-lib"
      ".local/bin/hypr-rofi-open-file"
      ".local/bin/hypr-rofi-open-file-dir"
      ".local/bin/hypr-rofi-open-file-terminal"
      ".local/bin/hypr-rofi-ssh-host"
      ".local/bin/hypr-rofi-window"
      ".local/bin/hypr-session-import-env"
      ".local/bin/hypr-reload-after-switch"
      ".local/bin/hypr-smart-run"
      ".local/bin/hypr-start-containers"
      ".local/bin/hypr-start-discord"
      ".local/bin/hypr-system-menu"
      ".local/bin/hypr-theme-chooser"
      ".local/bin/hypr-tools-menu"
      ".local/bin/hypr-transition-menu"
      ".local/bin/hypr-tray-applets"
      ".local/bin/hypr-tweaks-menu"
      ".local/bin/hypr-workspace-button"
      ".local/bin/hypr-wallpaper"
      ".local/bin/hypr-firefox-new-window"
      ".local/bin/waybar-caffeine-state"
      ".local/bin/waybar-date-es"
      ".local/bin/waybar-day-month-es"
      ".local/bin/waybar-metric-widget"
      ".local/bin/waybar-pi-status"
      ".local/bin/waybar-power-profile"
      ".local/bin/waybar-swap-usage"
      ".local/bin/waybar-time-ampm"
      ".local/bin/waybar-watch"
    ];

    i3 = [
      ".config/autostart/autorandr.desktop"
      ".config/Thunar/uca.xml"
      ".config/gtk-3.0"
      ".config/dunst"
      ".config/i3"
      ".config/xlogout"
      ".config/rofi"
      ".local/bin/i3-caffeine-toggle"
      ".local/bin/i3-calc"
      ".local/bin/i3-clipboard"
      ".local/bin/i3-config-editor"
      ".local/bin/i3-devices-menu"
      ".local/bin/i3-hotkeys"
      ".local/bin/i3-keyboard-menu"
      ".local/bin/i3-lock"
      ".local/bin/i3-lock-background"
      ".local/bin/i3-main-menu"
      ".local/bin/i3-monitor-profile"
      ".local/bin/i3-obsidian-open-or-focus"
      ".local/bin/i3-reload-after-switch"
      ".local/bin/i3-run"
      ".local/bin/i3-firefox-new-window"
      ".local/bin/i3-open-file"
      ".local/bin/i3-pi-prompt"
      ".local/bin/i3-performance-menu"
      ".local/bin/i3-powermenu"
      ".local/bin/i3-rofi"
      ".local/bin/i3-ssh-host"
      ".local/bin/i3-wallpaper"
      ".local/bin/i3-set-wallpaper"
      ".local/bin/i3-wifi-toggle"
      ".local/bin/i3status-localized"
    ];

    labwc = [
      ".config/dunst"
      ".config/labwc"
      ".config/rofi"
      ".config/waybar/config"
      ".config/waybar/style.css"
      ".config/waybar/kbd-layout.sh"
      ".config/waybar/macchiato.css"
      ".config/waybar/orgm.png"
      ".local/bin/labwc-kill-windows"
    ];

    gnome = [ ];
    cinnamon = [ ];
  };

  # Host-specific shared paths (Bash host config, desktop files, icons).
  # Source: dotfiles/config/hosts/<host>/<path>
  # Subdirectories of .local/share/icons that are host-specific.
  # .local/share/icons itself is intentionally NOT listed — doing so would
  # block sharedPaths from deploying .local/share/icons/hicolor/256x256/apps
  # (the priority filter removes shared child paths when a host parent exists).
  hostIconSubdirs = [
    ".local/share/icons/Nordic-bluish"
    ".local/share/icons/Nordic-darker"
    ".local/share/icons/Nordic-green"
    ".local/share/icons/hicolor/16x16"
    ".local/share/icons/hicolor/32x32"
    ".local/share/icons/hicolor/48x48"
    ".local/share/icons/hicolor/64x64"
    ".local/share/icons/hicolor/128x128"
  ];

  hostPaths = {
    ero = [
      ".config/bash/host-ero.bash"
    ]
    ++ hostIconSubdirs;
    lenovo = [
      ".config/bash/host-lenovo.bash"
      ".local/share/applications/desktop-apps.desktop"
      ".local/share/applications/dota.desktop"
      ".local/share/applications/silksong.desktop"
    ]
    ++ hostIconSubdirs;
    orgm = [
      ".config/bash/host-orgm.bash"
      ".local/share/applications/claude-code-url-handler.desktop"
      ".local/share/applications/desktop-apps.desktop"
      ".local/share/applications/dota.desktop"
      ".local/share/applications/silksong.desktop"
    ]
    ++ hostIconSubdirs;
    jarq = [
      ".config/bash/host-jarq.bash"
    ]
    ++ hostIconSubdirs;
  };

  # Host+profile paths — host-specific overrides per profile (monitor configs, etc.)
  # Source: dotfiles/config/hosts/<host>/<path>
  hostProfilePaths = {
    ero = {
      hyprland = [ ];
      i3 = [ ];
      labwc = [ ];
    };
    jarq = {
      hyprland = [ ];
      i3 = [ ];
      labwc = [ ];
    };
    lenovo = {
      hyprland = [
        ".config/DankMaterialShell"
        ".config/hypr/lua/monitors/lenovo.lua"
      ];
      i3 = [ ];
      labwc = [ ];
    };
    orgm = {
      hyprland = [
        ".config/DankMaterialShell"
        ".config/hypr/lua/monitors/orgm.lua"
        ".config/orgm-hypr/display-targets.json"
      ];
      i3 = [ ];
      labwc = [ ];
    };
  };

  localOnlyPaths = [
    ".config/autorandr"
    ".gtkrc-2.0"
    ".config/gtk-4.0/gtk-dark.css"
    ".config/gtk-4.0/gtk.css"
    ".pi/agent/agent-status.json"
    ".pi/agent/auth.json"
    ".pi/agent/extensions/.pi-lens"
    ".pi/agent/git"
    ".pi/agent/git/github.com/osmargm1202/pi-harness"
    ".pi/agent/git/github.com/osmargm1202/pi-skills"
    ".pi/agent/npm/pi-harness"
    ".pi/agent/npm/pi-skills"
    ".pi/agent/mcp-cache.json"
    ".pi/agent/mcp-npx-cache.json"
    ".pi/agent/mcp.json"
    ".pi/agent/mcp.json.bak-20260420-151836"
    ".pi/agent/orgm.json"
    ".pi/agent/pi-crash.log"
    ".pi/agent/settings.json"
    ".config/gtk-4.0/settings.ini"
    ".config/gtk-4.0/orgm-hypr-settings.ini"
    ".config/xsettingsd/xsettingsd.conf"
    ".icons/default/index.theme"
    ".config/hypr/monitors.conf"
    ".config/hypr/monitors.lua"
    ".config/hypr/workspaces.conf"
    ".config/hypr/workspaces.lua"
    ".config/nwg-displays/config"
    ".config/gtk-4.0/orgm-hypr-theme.css"
    ".config/qt5ct/qt5ct.conf"
    ".config/qt5ct/orgm-hypr.conf"
    ".config/qt5ct/colors/orgm-hypr.colors"
    ".config/qt6ct/qt6ct.conf"
    ".config/qt6ct/orgm-hypr.conf"
    ".config/qt6ct/colors/orgm-hypr.colors"
    ".config/Kvantum/kvantum.kvconfig"
    ".config/Kvantum/orgm-hypr/orgm-hypr.kvconfig"
    ".config/kdeglobals"
    ".config/kdeglobals.orgm-hypr"
    ".config/rofi/orgm-hypr-theme.rasi"
    ".config/kitty/orgm-hypr-theme.conf"
    ".config/waybar-hypr/orgm-hypr-theme.css"
    ".config/helix/themes/orgm-hypr.toml"
    ".config/kitty/current-theme.conf"
    ".config/kitty/skwd-theme.conf"
    ".config/orgm-hypr/display-targets.json"
    ".local/state/hypr-rofi-ssh-host"
    ".config/rofi/orgm-current.rasi"
    ".config/waybar/orgm-current.css"
    ".config/waybar-hypr/orgm-current.css"
    ".config/nwg-dock-hyprland/orgm-current.css"
    ".config/qt5ct/colors/orgm-current.colors"
    ".config/qt6ct/colors/orgm-current.colors"
    ".config/hypr/scheme/current.conf"
    ".local/state/orgm-theme/current"
    ".local/state/orgm-theme/current.env"

    ".local/share/icons/default/index.theme"
  ];
  localOnlyPatterns = [
    "**/.git"
    "**/.git/**"
    "**/.gitignore"
    "**/.DS_Store"
    "**/Icon?"
    "**/icon-theme.cache"
    "**/mimeinfo.cache"
    "**/*~"
    "**/*.bak"
  ];
  localOnlyTypes = [ "symlink" ];
  localDefaultsPaths = [
    ".config/rofi/orgm-current.rasi"
    ".config/waybar/orgm-current.css"
    ".config/waybar-hypr/orgm-current.css"
    ".config/nwg-dock-hyprland/orgm-current.css"
    ".config/hypr/scheme/current.conf"
    ".config/vesktop/settings/quickcss.css"
  ];

  # Hyprland's compositor, Waybar, and helper commands stay materialized
  # across profile switches. They are inert outside a Hyprland session, but
  # preserving them prevents i3 activation from deleting the configured menus,
  # top bar, and command surface required by the next Hyprland login.
  persistentHyprlandPaths = lib.filter (
    path:
    lib.hasPrefix ".config/hypr/" path
    || lib.hasPrefix ".config/orgm-hypr/" path
    || path == ".config/waybar-hypr"
    || lib.hasPrefix ".local/bin/hypr-" path
    || lib.hasPrefix ".local/bin/waybar-" path
  ) (profileSpecificPaths.hyprland or [ ]);
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
  currentProfilePaths = lib.filter (path: !builtins.elem path persistentHyprlandPaths) (
    profileSpecificPaths.${profileName} or [ ]
  );
  pathsForHost = hostPaths.${hostName} or [ ];
  pathsForHostProfile = (hostProfilePaths.${hostName} or { }).${profileName} or [ ];

  # Priority: hostProfilePaths > hostPaths > profilePaths > sharedPaths.
  # Persistent Hyprland paths are profile sources with the same priority as
  # the active profile, so host-specific monitor files can still override them.
  higherThanShared =
    persistentHyprlandPaths ++ currentProfilePaths ++ pathsForHost ++ pathsForHostProfile;
  higherThanProfile = pathsForHost ++ pathsForHostProfile;

  pass1SharedPaths = lib.filter (
    sp: !builtins.any (hp: sp == hp || lib.hasPrefix (hp + "/") sp) higherThanShared
  ) sharedPaths;

  pass1PersistentHyprlandPaths = lib.filter (
    pp:
    !builtins.any (hp: pp == hp || lib.hasPrefix (hp + "/") pp) (pathsForHost ++ pathsForHostProfile)
  ) persistentHyprlandPaths;

  pass1ProfilePaths = lib.filter (
    pp: !builtins.any (hp: pp == hp || lib.hasPrefix (hp + "/") pp) higherThanProfile
  ) currentProfilePaths;

  pass1HostPaths = lib.filter (
    hp: !builtins.any (hpp: hp == hpp || lib.hasPrefix (hpp + "/") hp) pathsForHostProfile
  ) pathsForHost;

  # Pass 2 — drop any path that has child paths in the combined list.
  pass1All =
    pass1SharedPaths
    ++ pass1PersistentHyprlandPaths
    ++ pass1ProfilePaths
    ++ pass1HostPaths
    ++ pathsForHostProfile;

  filteredSharedPaths = lib.filter (
    sp: !builtins.any (other: lib.hasPrefix (sp + "/") other) pass1All
  ) pass1SharedPaths;

  filteredPersistentHyprlandPaths = lib.filter (
    pp: !builtins.any (other: lib.hasPrefix (pp + "/") other) pass1All
  ) pass1PersistentHyprlandPaths;

  filteredProfilePaths = lib.filter (
    pp: !builtins.any (other: lib.hasPrefix (pp + "/") other) pass1All
  ) pass1ProfilePaths;

  filteredHostPaths = lib.filter (
    hp: !builtins.any (other: lib.hasPrefix (hp + "/") other) pass1All
  ) pass1HostPaths;

  filteredHostProfilePaths = lib.filter (
    hpp: !builtins.any (other: lib.hasPrefix (hpp + "/") other) pass1All
  ) pathsForHostProfile;
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
              .config/kitty .config/yazi
          '';
      # Reset the obsolete managed Yazi setup once. Only repo-owned links and
      # the known generated Matugen theme are removed; later local configuration
      # remains user-owned.
      home.activation.resetYaziConfiguration = lib.hm.dag.entryBefore [ "removeConflictingDotfiles" ] ''
        for path in \
          .config/yazi/yazi.toml \
          .config/yazi/keymap.toml \
          .config/yazi/package.toml \
          .config/yazi/flavors; do
          target="$HOME/$path"
          source="${dotfilesPath}/config/shared/$path"
          if [ -L "$target" ] && [ "$(${pkgs.coreutils}/bin/readlink -f -- "$target")" = "$source" ]; then
            $DRY_RUN_CMD ${pkgs.coreutils}/bin/rm "$target"
          fi
        done

        theme="$HOME/.config/yazi/theme.toml"
        if [ -f "$theme" ] && ${pkgs.gnugrep}/bin/grep -Fqx '# Matugen template: yazi file manager theme from wallpaper' "$theme"; then
          $DRY_RUN_CMD ${pkgs.coreutils}/bin/rm "$theme"
        fi
      '';

      # Keep user-level MIME preferences in sync with declarative defaults,
      # which take precedence over /etc/xdg/mimeapps.list.
      home.activation.setPreferredFileHandlers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        $DRY_RUN_CMD ${pkgs.xdg-utils}/bin/xdg-mime default yazi.desktop inode/directory
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
          ${lib.concatMapStringsSep "\n          " (p: ''"${p}"'') (
            filteredSharedPaths
            ++ filteredPersistentHyprlandPaths
            ++ filteredProfilePaths
            ++ filteredHostPaths
            ++ filteredHostProfilePaths
            ++ map (file: file.target) persistentHyprlandRofiFiles
          )}
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
        # Shared paths — dotfiles/config/shared/<path>
        (builtins.listToAttrs (
          map (path: {
            name = path;
            value.source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/config/shared/${path}";
          }) filteredSharedPaths
        ))
        # Persistent Hyprland paths — profile sources retained across switches.
        (builtins.listToAttrs (
          map (path: {
            name = path;
            value.source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/config/profiles/hyprland/${path}";
          }) filteredPersistentHyprlandPaths
        ))
        # Persistent Hyprland Rofi theme — separate from the active profile.
        (builtins.listToAttrs (
          map (file: {
            name = file.target;
            value.source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/config/profiles/hyprland/${file.source}";
          }) persistentHyprlandRofiFiles
        ))
        # Profile-specific paths — dotfiles/config/profiles/<profile>/<path>
        (builtins.listToAttrs (
          map (path: {
            name = path;
            value.source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/config/profiles/${profileDotfilesName}/${path}";
          }) filteredProfilePaths
        ))
        # Host paths — dotfiles/config/hosts/<host>/<path>
        (builtins.listToAttrs (
          map (path: {
            name = path;
            value = lib.mkForce {
              source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/config/hosts/${hostName}/${path}";
            };
          }) filteredHostPaths
        ))
        # Host+profile paths — dotfiles/config/hosts/<host>/<path>
        (builtins.listToAttrs (
          map (path: {
            name = path;
            value = lib.mkForce {
              source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/config/hosts/${hostName}/${path}";
            };
          }) filteredHostProfilePaths
        ))
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
        # Force overwrite for migration/transition artifact that can exist from prior manual copies.
        {
          ".local/bin/hypr-video-timer" = lib.mkForce {
            force = true;
            source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/config/shared/.local/bin/hypr-video-timer";
          };
        }
      ];
    };

  environment.systemPackages = [ orgmDotfilesUpdateScript ];

  assertions = [
    {
      assertion = localOnlyPaths != [ ] && localOnlyPatterns != [ ] && localOnlyTypes != [ ];
      message = "common-dotfiles.nix must keep local_only inventory from dotfiles.json as exclusions/documentation";
    }
    {
      assertion = localDefaultsPaths != [ ];
      message = "common-dotfiles.nix must keep local_defaults inventory from dotfiles.json as documentation";
    }
  ];
}
