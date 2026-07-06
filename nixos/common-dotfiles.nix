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

  orgmDotfilesUpdateScript = pkgs.writeShellApplication {
    name = "orgm-dotfiles-update";
    runtimeInputs = with pkgs; [ git openssh ];
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
    # Fish — listed individually so host-specific files (host-orgm.fish etc.)
    # can coexist without the directory-level symlink being dropped by the filter.
    ".config/fish/age.fish"
    ".config/fish/completions/aichat.fish"
    ".config/fish/completions/ftdv.fish"
    ".config/fish/conf.d/command-separator.fish"
    ".config/fish/conf.d/fish_frozen_key_bindings.fish"
    ".config/fish/conf.d/fnm.fish"
    ".config/fish/config.fish"
    ".config/fish/functions/aichat_fish.fish"
    ".config/fish/functions/airplane_mode_toggle.fish"
    ".config/fish/functions/archive-preview.fish"
    ".config/fish/functions/autostart.fish"
    ".config/fish/functions/back-op.fish"
    ".config/fish/functions/backtrack-op.fish"
    ".config/fish/functions/bluetooth_toggle.fish"
    ".config/fish/functions/bookmark_add.fish"
    ".config/fish/functions/bookmark_delete.fish"
    ".config/fish/functions/bookmark_to_type.fish"
    ".config/fish/functions/check_airplane_mode.fish"
    ".config/fish/functions/check_geo_module.fish"
    ".config/fish/functions/check_night_mode.fish"
    ".config/fish/functions/check_recording.fish"
    ".config/fish/functions/check_webcam.fish"
    ".config/fish/functions/clear-op.fish"
    ".config/fish/functions/clipboard_clear.fish"
    ".config/fish/functions/clipboard_copy.fish"
    ".config/fish/functions/clipboard_delete_item.fish"
    ".config/fish/functions/clipboard_to_type.fish"
    ".config/fish/functions/clipboard_to_wlcopy.fish"
    ".config/fish/functions/dir-preview.fish"
    ".config/fish/functions/dunst_pause.fish"
    ".config/fish/functions/fetch_music_player_data.fish"
    ".config/fish/functions/file-preview.fish"
    ".config/fish/functions/fish_bind_count.fish"
    ".config/fish/functions/fish_default_mode_prompt.fish"
    ".config/fish/functions/fish_helix_command.fish"
    ".config/fish/functions/fish_helix_key_bindings.fish"
    ".config/fish/functions/fish_user_key_bindings.fish"
    ".config/fish/functions/fzf-cd-preview-widget.fish"
    ".config/fish/functions/fzf-file-preview-widget.fish"
    ".config/fish/functions/fzf_key_bindings.fish"
    ".config/fish/functions/fzf-ps-widget.fish"
    ".config/fish/functions/image-preview.fish"
    ".config/fish/functions/kitty_launch.fish"
    ".config/fish/functions/list-op.fish"
    ".config/fish/functions/load_private_env.fish"
    ".config/fish/functions/night_mode_temp_down.fish"
    ".config/fish/functions/night_mode_temp_up.fish"
    ".config/fish/functions/night_mode_toggle.fish"
    ".config/fish/functions/private-env-decrypt.fish"
    ".config/fish/functions/private-env-edit.fish"
    ".config/fish/functions/private-env-encrypt.fish"
    ".config/fish/functions/record_screen_gif.fish"
    ".config/fish/functions/record_screen_mp4.fish"
    ".config/fish/functions/screenshot_edit.fish"
    ".config/fish/functions/screenshot_to_clipboard.fish"
    ".config/fish/functions/switch-preview.fish"
    ".config/fish/functions/__tmux_init.fish"
    ".config/fish/functions/__tmux_shared.fish"
    ".config/fish/functions/tmux.fish"
    ".config/fish/functions/tmuxdel.fish"
    ".config/fish/functions/tmuxfd.fish"
    ".config/fish/functions/tmuxls.fish"
    ".config/fish/functions/tmuxnew.fish"
    ".config/fish/functions/tmuxnewz.fish"
    ".config/fish/functions/tre.fish"
    ".config/fish/functions/unbindheadset.fish"
    ".config/fish/functions/wifi_toggle.fish"
    ".config/fish/functions/wlogout_uniqe.fish"
    ".config/fish/icons/camera_gif_icon.png"
    ".config/fish/icons/camera_mp4_icon.png"
    ".config/fish/icons/rec_icon.png"
    ".config/fish/private-env.fish.age"
    ".config/helix"
    ".config/kitty"
    ".config/mpv"
    ".config/nvim"
    ".config/posting"
    ".config/starship.toml"
    ".config/wallpapers"
    ".config/warp-terminal/settings.toml"
    ".config/yazi"
    ".config/zathura"
    ".config/zellij"
    ".icons"
    ".local/bin/kbd-layout-next"
    ".local/bin/memclean-dev"
    ".local/bin/brightness-osd"
    ".local/bin/reset_config"
    ".local/bin/windows-rdp"
    ".local/share/icons/hicolor/256x256/apps"
    ".local/share/applications/windows-rdp.desktop"
    ".local/share/icons/nixos.svg"
    ".local/share/icons/windows.png"
    ".local/share/posting"
    ".local/share/themes"
    ".pi/agent/AGENTS.md"
    ".pi/agent/RTK.md"
    ".pi/agent/ask.jsonc"
    ".tmux.conf"
  ];

  # Profile-specific paths — only symlinked when matching profile is active.
  # Currently sourced from dotfiles/config/shared/<path>; move to
  # dotfiles/config/profiles/<profile>/<path> when dotfiles repo is reorganised.
  profileSpecificPaths = {
    hyprland = [
      ".config/Kvantum/catppuccin-macchiato-teal-standard#"
      ".config/conky/conky.conf"
      ".config/conky/conky-apps.conf"
      ".config/conky/conky-clock.conf"
      ".config/conky/conky-top.conf"
      ".config/conky/conky-top-clock.conf"
      ".config/conky/conky-top-apps.conf"
      ".config/conky/conky-draw.lua"
      ".config/dunst"
      ".config/fuzzel"
      ".config/gtk-4.0/noctalia.css"
      ".config/gtk-4.0/colors.css"
      ".config/gtk-4.0/thunar.css"
      ".config/gtk-4.0/dank-colors.css"
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
      ".config/hypr/wallpaper-picker/README.md"
      ".config/hypr/wallpaper-picker/wallpaper_picker.py"
      ".config/niri/00-startup.kdl"
      ".config/niri/10-workspace.kdl"
      ".config/niri/30-input.kdl"
      ".config/niri/40-layout.kdl"
      ".config/niri/50-visuals.kdl"
      ".config/niri/60-animations.kdl"
      ".config/niri/70-window-rules.kdl"
      ".config/niri/80-binds.kdl"
      ".config/niri/90-overview.kdl"
      ".config/niri/95-other.kdl"
      ".config/niri/config.kdl"
      ".config/niri/dms/alttab.kdl"
      ".config/niri/dms/colors.kdl"
      ".config/niri/dms/empty_binds.kdl"
      ".config/niri/dms/empty_cursor.kdl"
      ".config/niri/dms/empty_windowrules.kdl"
      ".config/niri/dms/layout.kdl"
      ".config/niri/dms/wpblur.kdl"
      ".config/nwg-dock-hyprland/style.css"
      ".config/orgm-hypr/notify-focus.json"
      ".config/orgm-hypr/themes.json"
      ".config/orgm-theme"
      ".config/qt5ct/colors/caelestia.colors"
      ".config/qt6ct/colors/caelestia.colors"
      ".config/quickshell/theme/orgm-dark.json"
      ".config/quickshell/theme/orgm-light.json"
      ".config/quickshell/wallpaper-picker"
      ".config/quickshell/modules"
      ".config/rofi"
      ".config/swappy"
      ".config/swaync/config.json"
      ".config/swaync/style.css"
      ".config/waybar-hypr/config"
      ".config/waybar-hypr/style.css"
      ".config/waybar-hypr/kbd-layout.sh"
      ".config/waybar-hypr/macchiato.css"
      ".config/waybar-hypr/orgm.png"
      ".config/waybar-hypr/orgm-hypr.png"
      ".config/waybar-hypr/icons"
      ".config/wlogout"
      ".config/wofi"
      ".local/bin/conky-gpu-stat"
      ".local/bin/hypr-apps-menu"
      ".local/bin/hypr-battery-alerts"
      ".local/bin/hypr-app-launcher"
      ".local/bin/hypr-audio-device-menu"
      ".local/bin/hypr-bluetooth-menu"
      ".local/bin/hypr-bluetooth-reconnect"
      ".local/bin/hypr-config-editor"
      ".local/bin/hypr-conky-toggle"
      ".local/bin/hypr-current-wallpaper"
      ".local/bin/hypr-devices-menu"
      ".local/bin/hypr-display-targets"
      ".local/bin/hypr-focus-notification-app"
      ".local/bin/hypr-help-menu"
      ".local/bin/hypr-keybindings-help"
      ".local/bin/hypr-keyhelper"
      ".local/bin/hypr-keyboard-menu"
      ".local/bin/hypr-kill-windows"
      ".local/bin/hypr-lock"
      ".local/bin/hypr-main-menu"
      ".local/bin/hypr-nwg-dock"
      ".local/bin/hypr-obsidian-open-or-focus"
      ".local/bin/hypr-performance-menu"
      ".local/bin/hypr-pi-prompt"
      ".local/bin/hypr-power-menu"
      ".local/bin/hypr-random-wallpaper"
      ".local/bin/hypr-rofi-calc"
      ".local/bin/hypr-rofi-clipboard"
      ".local/bin/hypr-rofi-lib"
      ".local/bin/hypr-rofi-open-file"
      ".local/bin/hypr-rofi-open-file-dir"
      ".local/bin/hypr-rofi-open-file-terminal"
      ".local/bin/hypr-rofi-ssh-host"
      ".local/bin/hypr-rofi-tmux-arch"
      ".local/bin/hypr-rofi-window"
      ".local/bin/hypr-session-import-env"
      ".local/bin/hypr-smart-run"
      ".local/bin/hypr-start-containers"
      ".local/bin/hypr-start-discord"
      ".local/bin/hypr-system-menu"
      ".local/bin/hypr-theme-chooser"
      ".local/bin/hypr-tools-menu"
      ".local/bin/hypr-transition-menu"
      ".local/bin/hypr-tweaks-menu"
      ".local/bin/hypr-usb-menu"
      ".local/bin/hypr-webapp-maker"
      ".local/bin/hypr-webapp-remover"
      ".local/bin/hypr-wifi-menu"
      ".local/bin/hypr-workspace-button"
      ".local/bin/hypr-zen-new-window"
      ".local/bin/waybar-date-es"
      ".local/bin/waybar-day-month-es"
      ".local/bin/waybar-metric-widget"
      ".local/bin/waybar-pi-status"
      ".local/bin/waybar-power-profile"
      ".local/bin/waybar-swap-usage"
      ".local/bin/waybar-theme-toggle"
      ".local/bin/waybar-time-ampm"
      ".local/bin/waybar-watch"
      ".local/bin/mic-volume-osd"
      ".local/bin/volume-osd"
    ];

    i3 = [
      ".config/conky"
      ".config/dunst"
      ".config/i3"
      ".config/picom"
      ".config/polybar"
      ".config/rofi"
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

    hyprlandqs-caelestia = [
      ".config/hypr/hyprland.lua"
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
      ".config/hypr/wallpaper-picker"
      ".config/orgm-hypr/notify-focus.json"
      ".config/orgm-hypr/themes.json"
      ".config/orgm-theme"
      ".config/rofi"
      ".config/swappy"
      ".config/wlogout"
      ".local/bin/hypr-battery-alerts"
      ".local/bin/hypr-app-launcher"
      ".local/bin/hypr-audio-device-menu"
      ".local/bin/hypr-bluetooth-menu"
      ".local/bin/hypr-bluetooth-reconnect"
      ".local/bin/hypr-devices-menu"
      ".local/bin/hypr-display-targets"
      ".local/bin/hypr-keyboard-menu"
      ".local/bin/hypr-kill-windows"
      ".local/bin/hypr-lock"
      ".local/bin/hypr-current-wallpaper"
      ".local/bin/hypr-nwg-dock"
      ".local/bin/hypr-qs-menu"
      ".local/bin/hypr-obsidian-open-or-focus"
      ".local/bin/hypr-performance-menu"
      ".local/bin/hypr-pi-prompt"
      ".local/bin/hypr-power-menu"
      ".local/bin/hypr-random-wallpaper"
      ".local/bin/hypr-rofi-calc"
      ".local/bin/hypr-rofi-clipboard"
      ".local/bin/hypr-rofi-lib"
      ".local/bin/hypr-rofi-open-file"
      ".local/bin/hypr-rofi-ssh-host"
      ".local/bin/hypr-session-import-env"
      ".local/bin/hypr-smart-run"
      ".local/bin/hypr-usb-menu"
      ".local/bin/hypr-wallpaper-picker"
      ".local/bin/hypr-wallpaper-picker-dark"
      ".local/bin/hypr-wallpaper-picker-light"
      ".local/bin/hypr-webapp-maker"
      ".local/bin/hypr-wifi-menu"
      ".local/bin/hypr-zen-new-window"
      ".local/bin/orgm-wallpaper"
      ".local/bin/mic-volume-osd"
      ".local/bin/volume-osd"
    ];

    xfce     = [];
    mate     = [];
    gnome    = [];
    cinnamon = [];
  };

  # Host-specific shared paths (fish host config, desktop files, icons).
  # Source: dotfiles/config/hosts/<host>/<path>
  # Subdirectories of .local/share/icons that are host-specific.
  # .local/share/icons itself is intentionally NOT listed — doing so would
  # block sharedPaths from deploying .local/share/icons/hicolor/256x256/apps
  # (the priority filter removes shared child paths when a host parent exists).
  hostIconSubdirs = [
    ".local/share/icons/Nordic-bluish"
    ".local/share/icons/Nordic-darker"
    ".local/share/icons/Nordic-green"
    ".local/share/icons/distrobox"
    ".local/share/icons/default"
    ".local/share/icons/hicolor/16x16"
    ".local/share/icons/hicolor/32x32"
    ".local/share/icons/hicolor/48x48"
    ".local/share/icons/hicolor/64x64"
    ".local/share/icons/hicolor/128x128"
  ];

  hostPaths = {
    ero = [
      ".config/fish/age-host.fish"
      ".config/fish/host-ero.fish"
    ] ++ hostIconSubdirs;
    lenovo = [
      ".config/fish/age-host.fish"
      ".config/fish/host-lenovo.fish"
      ".local/share/applications/arch.desktop"
      ".local/share/applications/desktop-apps.desktop"
      ".local/share/applications/dota.desktop"
      ".local/share/applications/jsignpdf.desktop"
      ".local/share/applications/opencode.desktop"
      ".local/share/applications/silksong.desktop"
      ".local/share/applications/vscode.desktop"
      ".local/share/applications/webapps.json"
      ".local/share/applications/zed.desktop"
    ] ++ hostIconSubdirs;
    orgm = [
      ".config/fish/age-host.fish"
      ".config/fish/host-orgm.fish"
      ".local/share/applications/claude-code-url-handler.desktop"
      ".local/share/applications/desktop-apps.desktop"
      ".local/share/applications/dota.desktop"
      ".local/share/applications/opencode.desktop"
      ".local/share/applications/silksong.desktop"
      ".local/share/applications/webapps.json"
    ] ++ hostIconSubdirs;
    jarq = [
      ".config/fish/age-host.fish"
      ".config/fish/host-jarq.fish"
    ] ++ hostIconSubdirs;
  };

  # Host+profile paths — host-specific overrides per profile (monitor configs, etc.)
  # Source: dotfiles/config/hosts/<host>/<path>
  hostProfilePaths = {
    ero    = { hyprland = []; i3 = []; labwc = []; hyprlandqs-caelestia = []; };
    jarq   = { hyprland = []; i3 = []; labwc = []; hyprlandqs-caelestia = []; };
    lenovo = {
      hyprland = [
        ".config/DankMaterialShell"
        ".config/hypr/lua/monitors/lenovo.lua"
        ".config/niri/20-output.kdl"
        ".config/rofi/hypr-menu.env"
      ];
      hyprlandqs-caelestia = [
        ".config/hypr/lua/monitors/lenovo.lua"
        ".config/rofi/hypr-menu.env"
      ];
      i3 = [];
      labwc = [];
    };
    orgm = {
      hyprland = [
        ".config/DankMaterialShell"
        ".config/hypr/lua/monitors/orgm.lua"
        ".config/niri/20-output.kdl"
        ".config/niri/dms/outputs.kdl"
        ".config/orgm-hypr/display-targets.json"
        ".config/rofi/hypr-menu.env"
      ];
      hyprlandqs-caelestia = [
        ".config/hypr/lua/monitors/orgm.lua"
        ".config/orgm-hypr/display-targets.json"
        ".config/rofi/hypr-menu.env"
      ];
      i3 = [];
      labwc = [];
    };
  };

  localOnlyPaths = [
    ".config/fish/fish_variables"
    ".config/fish/functions/dir.txt"
    ".config/fish/insforge.env"
    ".config/fish/pdd"
    ".config/fish/private-env.fish"
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
    ".config/gtk-3.0"
    ".config/gtk-4.0/settings.ini"
    ".config/gtk-4.0/orgm-hypr-settings.ini"
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
    ".config/nwg-dock-hyprland/orgm-hypr-theme.css"
    ".config/helix/themes/orgm-hypr.toml"
    ".config/kitty/current-theme.conf"
    ".config/orgm-hypr/display-targets.json"
    ".local/state/hypr-rofi-ssh-host"
    ".config/rofi/orgm-current.rasi"
    ".config/waybar/orgm-current.css"
    ".config/waybar-hypr/orgm-current.css"
    ".config/nwg-dock-hyprland/orgm-current.css"
    ".config/swaync/orgm-current.css"
    ".config/qt5ct/colors/orgm-current.colors"
    ".config/qt6ct/colors/orgm-current.colors"
    ".config/hypr/scheme/current.conf"
    ".local/state/orgm-theme/current"
    ".local/state/orgm-theme/current.env"
    ".config/quickshell/theme/theme.json"
    ".config/quickshell/theme/current.json"
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
    ".config/swaync/orgm-current.css"
    ".config/hypr/scheme/current.conf"
    ".config/quickshell/theme/theme.json"
    ".config/vesktop/settings/quickcss.css"
  ];

  currentProfilePaths = profileSpecificPaths.${profileName} or [];
  pathsForHost        = hostPaths.${hostName} or [];
  pathsForHostProfile = (hostProfilePaths.${hostName} or {}).${profileName} or [];

  # Priority: hostProfilePaths > hostPaths > profilePaths > sharedPaths
  # Pass 1 — drop lower-priority paths that are children of higher-priority dirs
  higherThanShared = currentProfilePaths ++ pathsForHost ++ pathsForHostProfile;
  higherThanProfile = pathsForHost ++ pathsForHostProfile;

  pass1SharedPaths = lib.filter (sp:
    !builtins.any (hp: lib.hasPrefix (hp + "/") sp) higherThanShared
  ) sharedPaths;

  pass1ProfilePaths = lib.filter (pp:
    !builtins.any (hp: lib.hasPrefix (hp + "/") pp) higherThanProfile
  ) currentProfilePaths;

  pass1HostPaths = lib.filter (hp:
    !builtins.any (hpp: lib.hasPrefix (hpp + "/") hp) pathsForHostProfile
  ) pathsForHost;

  # Pass 2 — drop any path that has child paths in the combined list
  pass1All = pass1SharedPaths ++ pass1ProfilePaths ++ pass1HostPaths ++ pathsForHostProfile;

  filteredSharedPaths = lib.filter (sp:
    !builtins.any (other: lib.hasPrefix (sp + "/") other) pass1All
  ) pass1SharedPaths;

  filteredProfilePaths = lib.filter (pp:
    !builtins.any (other: lib.hasPrefix (pp + "/") other) pass1All
  ) pass1ProfilePaths;

  filteredHostPaths = lib.filter (hp:
    !builtins.any (other: lib.hasPrefix (hp + "/") other) pass1All
  ) pass1HostPaths;

  filteredHostProfilePaths = lib.filter (hpp:
    !builtins.any (other: lib.hasPrefix (hpp + "/") other) pass1All
  ) pathsForHostProfile;
in
{
  systemd.tmpfiles.rules = [
    "d ${dotfilesParent} 0755 ${userName} users - -"
  ];

  # Ensure the graphical login (and thus the Hyprland/niri session it spawns)
  # starts only after home-manager has finished linking the dotfiles. Without
  # this ordering the compositor can read its config before the lua/*.lua
  # symlinks exist, making every require() fail and dropping Hyprland into
  # emergency mode. `wants` (not `requires`) so a home-manager failure degrades
  # gracefully instead of blocking login entirely.
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
    after = [ "network-online.target" "orgm-dotfiles-repo.service" ];
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
    { config, lib, pkgs, ... }:
    {
      home.packages = lib.mkIf (profileName == "hyprland") [ pkgs.conky ];

      home.activation.removeConflictingDotfiles = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
        if [ -L "$HOME/.local/share/applications" ]; then
          $DRY_RUN_CMD rm "$HOME/.local/share/applications"
        fi

        for old_dir in \
          .config/hypr \
          .config/niri \
          .config/orgm-hypr \
          .config/waybar .config/waybar-hypr \
          .config/swaync .config/nwg-dock-hyprland \
          .config/qt5ct .config/qt6ct \
          .config/quickshell .config/gtk-4.0 \
          .config/Kvantum \
          .config/i3 .config/polybar .config/picom \
          .config/labwc \
          .config/conky \
          .local/share/icons; do
          target="$HOME/$old_dir"
          if [ -L "$target" ]; then
            $DRY_RUN_CMD rm "$target"
          fi
        done

        declare -a managed_paths=(
          ${lib.concatMapStringsSep "\n          " (p: ''"${p}"'') (filteredSharedPaths ++ filteredProfilePaths ++ filteredHostPaths ++ filteredHostProfilePaths)}
        )
        for p in "''${managed_paths[@]}"; do
          target="$HOME/$p"
          if [ -e "$target" ] && [ ! -L "$target" ]; then
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
          if [ ! -e "$HOME/.config/gtk-4.0/settings.ini" ]; then
            mkdir -p "$HOME/.config/gtk-4.0"
            cat > "$HOME/.config/gtk-4.0/settings.ini" << 'GTKEOF'
[Settings]
gtk-theme-name=Adwaita-dark
gtk-application-prefer-dark-theme=true
gtk-icon-theme-name=Papirus-Dark
gtk-cursor-theme-name=Catppuccin-Macchiato-Teal-Cursors
gtk-cursor-theme-size=36
gtk-font-name=Inter 11
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=none
gtk-overlay-scrolling=true
GTKEOF
          fi
        ''
        + lib.optionalString (profileName == "hyprland") ''
          init_file ".config/waybar/orgm-current.css"            "/* generated by orgm-themes */"
          init_file ".config/waybar-hypr/orgm-current.css"       "/* generated by orgm-themes */"
          init_file ".config/nwg-dock-hyprland/orgm-current.css" "/* generated by orgm-themes */"
          init_file ".config/swaync/orgm-current.css"            "/* generated by orgm-themes */"
          init_file ".config/rofi/orgm-current.rasi"             "/* generated by orgm-themes */"
          init_file ".config/gtk-4.0/gtk.css"      "/* generated by orgm-themes */"
          init_file ".config/gtk-4.0/gtk-dark.css" "/* generated by orgm-themes */"
          init_file ".config/qt5ct/qt5ct.conf"     ""
          init_file ".config/qt5ct/colors/orgm-current.colors" ""
          init_file ".config/qt6ct/qt6ct.conf"     ""
          init_file ".config/qt6ct/colors/orgm-current.colors" ""
          init_file ".config/Kvantum/kvantum.kvconfig" ""
          init_file ".config/kdeglobals"            ""
          init_file ".config/hypr/scheme/current.conf" "# generated by orgm-themes"
          init_file ".config/quickshell/theme/theme.json"   "{}"
          init_file ".config/quickshell/theme/current.json" "{}"
          init_file ".local/state/orgm-theme/current"     "orgm-dark"
          init_file ".local/state/orgm-theme/current.env" ""
          init_file ".config/vesktop/settings/quickcss.css" "/* generated by orgm-themes */"
        ''
        + lib.optionalString (profileName == "hyprlandqs-caelestia") ''
          init_file ".config/gtk-4.0/gtk.css"      ""
          init_file ".config/gtk-4.0/gtk-dark.css" ""
          init_file ".config/qt5ct/qt5ct.conf"     ""
          init_file ".config/qt6ct/qt6ct.conf"     ""
          init_file ".config/Kvantum/kvantum.kvconfig" ""
          init_file ".config/kdeglobals"            ""
          init_file ".config/hypr/scheme/current.conf" ""
          init_file ".config/vesktop/settings/quickcss.css" ""
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
        # Profile-specific paths — dotfiles/config/profiles/<profile>/<path>
        (builtins.listToAttrs (
          map (path: {
            name = path;
            value.source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/config/profiles/${profileName}/${path}";
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
