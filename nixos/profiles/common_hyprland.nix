{
  config,
  pkgs,
  lib,
  inputs,
  userName ? "osmarg",
  ...
}:

let
  system = pkgs.stdenv.hostPlatform.system;
  hyprlandPkgs = inputs.hyprland.packages.${system};
  hyprpaperPkg = inputs.hyprpaper.packages.${system}.hyprpaper;
  dotfilesOrgmSource = ../../dotfiles;
  orgmWallpaper = pkgs.callPackage ../packages/orgm-wallpaper.nix { inherit dotfilesOrgmSource; };
  orgmThemes = pkgs.callPackage ../packages/orgm-themes.nix { inherit dotfilesOrgmSource; };
  sddmKwinOutputConfig = ../hosts/${config.networking.hostName}/sddm-kwinoutputconfig.json;
  hasSddmKwinOutputConfig = builtins.pathExists sddmKwinOutputConfig;
in
{
  imports = [
    inputs.ltmnight-sddm-theme.nixosModules.default
    ./printer.nix
  ];

  services.xserver.enable = false;
  services.displayManager = {
    defaultSession = "hyprland";
    sddm = {
      enable = true;
      wayland = {
        enable = true;
        compositor = "kwin";
      };
      autoNumlock = true;
      enableHidpi = true;
      theme = "ltmnight";
      settings = {
        General.Numlock = "on";
        Wayland = {
          CursorTheme = "catppuccin-macchiato-teal-cursors";
          CursorSize = 36;
        };
      };
    };
  };

  environment.etc = lib.mkIf hasSddmKwinOutputConfig {
    "sddm/kwinoutputconfig-${config.networking.hostName}.json".source = sddmKwinOutputConfig;
  };
  systemd.tmpfiles.rules = lib.optionals hasSddmKwinOutputConfig [
    "d /var/lib/sddm/.config 0755 sddm sddm -"
    "C /var/lib/sddm/.config/kwinoutputconfig.json 0644 sddm sddm - /etc/sddm/kwinoutputconfig-${config.networking.hostName}.json"
  ];

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    package = hyprlandPkgs.hyprland;
    portalPackage = hyprlandPkgs.xdg-desktop-portal-hyprland;
  };

  security.polkit = {
    enable = true;
    extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (subject.user == "osmarg" && action.id.indexOf("org.freedesktop.color-manager.") == 0) {
          return polkit.Result.YES;
        }
      });
    '';
  };
  security.pam.services.sddm.enableGnomeKeyring = true;
  security.pam.services.login.enableGnomeKeyring = true;

  programs.nautilus-open-any-terminal = {
    enable = true;
    terminal = "kitty";
  };

  services.power-profiles-daemon.enable = true;
  # UPower DBus daemon — caelestia/quickshell BatteryMonitor reads battery via
  # Quickshell.Services.UPower; without it the shell reports "no battery".
  services.upower.enable = true;

  services.dbus.enable = true;
  services.udisks2.enable = true;
  services.gvfs.enable = true;
  services.gnome.gnome-keyring.enable = true;
  programs.dconf.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      hyprlandPkgs.xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];
    config = {
      common.default = [
        "hyprland"
        "gtk"
      ];
      hyprland.default = lib.mkForce [
        "hyprland"
        "gtk"
      ];
    };
  };

  xdg.terminal-exec = {
    enable = true;
    settings = {
      Hyprland = [ "kitty.desktop" ];
      default = [ "kitty.desktop" ];
    };
  };

  home-manager.users.${userName} =
    { lib, pkgs, ... }:
    let
      mimeAppsDefaults = pkgs.writeText "mimeapps-defaults.list" ''
        [Default Applications]
        inode/directory=org.gnome.Nautilus.desktop
        text/plain=org.gnome.TextEditor.desktop
        text/markdown=org.gnome.TextEditor.desktop
        text/x-markdown=org.gnome.TextEditor.desktop
        text/x-lua=org.gnome.TextEditor.desktop
        text/x-python=org.gnome.TextEditor.desktop
        application/json=org.gnome.TextEditor.desktop
        application/x-shellscript=org.gnome.TextEditor.desktop
        text/html=app.zen_browser.zen.desktop
        application/xhtml+xml=app.zen_browser.zen.desktop
        x-scheme-handler/http=app.zen_browser.zen.desktop
        x-scheme-handler/https=app.zen_browser.zen.desktop
        x-scheme-handler/chrome=app.zen_browser.zen.desktop
        application/pdf=org.gnome.Evince.desktop
        image/png=org.gnome.Loupe.desktop
        image/jpeg=org.gnome.Loupe.desktop
        image/webp=org.gnome.Loupe.desktop
        image/gif=org.gnome.Loupe.desktop
        image/svg+xml=org.gnome.Loupe.desktop
        application/zip=org.gnome.FileRoller.desktop
        application/x-tar=org.gnome.FileRoller.desktop
        application/x-7z-compressed=org.gnome.FileRoller.desktop
        application/x-rar=org.gnome.FileRoller.desktop
      '';
    in
    {
      home.activation.mimeAppsDefaults = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        mime_cfg="$HOME/.config/mimeapps.list"
        if [ ! -f "$mime_cfg" ]; then
          $DRY_RUN_CMD mkdir -p "$(dirname "$mime_cfg")"
          $DRY_RUN_CMD cp ${mimeAppsDefaults} "$mime_cfg"
        fi
      '';
    };

  xdg.mime = {
    enable = true;
    defaultApplications = {
      "inode/directory" = [ "org.gnome.Nautilus.desktop" ];
      "text/plain" = [ "org.gnome.TextEditor.desktop" ];
      "text/markdown" = [ "org.gnome.TextEditor.desktop" ];
      "text/x-markdown" = [ "org.gnome.TextEditor.desktop" ];
      "text/x-lua" = [ "org.gnome.TextEditor.desktop" ];
      "text/x-python" = [ "org.gnome.TextEditor.desktop" ];
      "application/json" = [ "org.gnome.TextEditor.desktop" ];
      "application/x-shellscript" = [ "org.gnome.TextEditor.desktop" ];
      "text/html" = [ "app.zen_browser.zen.desktop" ];
      "application/xhtml+xml" = [ "app.zen_browser.zen.desktop" ];
      "x-scheme-handler/http" = [ "app.zen_browser.zen.desktop" ];
      "x-scheme-handler/https" = [ "app.zen_browser.zen.desktop" ];
      "x-scheme-handler/chrome" = [ "app.zen_browser.zen.desktop" ];
      "application/pdf" = [ "org.gnome.Evince.desktop" ];
      "image/png" = [ "org.gnome.Loupe.desktop" ];
      "image/jpeg" = [ "org.gnome.Loupe.desktop" ];
      "image/webp" = [ "org.gnome.Loupe.desktop" ];
      "image/gif" = [ "org.gnome.Loupe.desktop" ];
      "image/svg+xml" = [ "org.gnome.Loupe.desktop" ];
      "application/zip" = [ "org.gnome.FileRoller.desktop" ];
      "application/x-tar" = [ "org.gnome.FileRoller.desktop" ];
      "application/x-7z-compressed" = [ "org.gnome.FileRoller.desktop" ];
      "application/x-rar" = [ "org.gnome.FileRoller.desktop" ];
    };
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
    XDG_SESSION_TYPE = "wayland";
    XDG_SESSION_DESKTOP = "Hyprland";
    XDG_CURRENT_DESKTOP = "Hyprland";
    QT_QPA_PLATFORM = "wayland";
    QT_QPA_PLATFORMTHEME = "qt5ct";
    QT_QPA_PLATFORMTHEME_QT6 = "qt6ct";
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
    GDK_BACKEND = "wayland,x11";
    SDL_VIDEODRIVER = "wayland";
    CLUTTER_BACKEND = "wayland";
    TERMINAL = "kitty";
  };

  environment.systemPackages = with pkgs; [
    # Hyprland-native stack
    hyprlandPkgs.hyprland
    xwayland
    hyprpaperPkg
    mpvpaper
    matugen
    orgmWallpaper
    orgmThemes
    libnotify
    ffmpeg
    python3Minimal
    hypridle
    hyprpicker
    hyprsunset
    hyprpolkitagent

    # Terminal
    kitty

    # Portal / XDG
    xdg-utils
    desktop-file-utils
    xdg-desktop-portal
    hyprlandPkgs.xdg-desktop-portal-hyprland
    xdg-desktop-portal-gtk

    # Clipboard / screenshots / wlroots-compatible tools
    wl-clipboard
    cliphist
    grim
    slurp
    swappy
    wl-screenrec
    wtype

    # Hardware controls
    brightnessctl
    udiskie
    usbutils
    pamixer
    playerctl
    pavucontrol
    networkmanagerapplet
    bluetui
    blueman
    overskride
    iwgtk

    # Communication
    vesktop

    # GNOME apps used as defaults
    nautilus
    gnome-text-editor
    apostrophe
    loupe
    evince
    totem
    mpv
    file-roller
    baobab
    gnome-calculator
    gnome-disk-utility
    gnome-logs
    gnome-system-monitor
    seahorse
    gnome-font-viewer
    gnome-characters
    sushi
    warehouse
    gnome-software

    # Desktop integration / theming
    gsettings-desktop-schemas
    adwaita-icon-theme
    papirus-icon-theme
    hicolor-icon-theme
    gnome-themes-extra
    gnome-tweaks
    yaru-remix-theme
    catppuccin-gtk
    catppuccin-cursors.macchiatoTeal
    catppuccin-cursors.latteTeal
    colloid-icon-theme
    libsForQt5.qtstyleplugin-kvantum
    libsForQt5.qt5ct
    qt5.qtwayland
    kdePackages.qtstyleplugin-kvantum
    qt6Packages.qt6ct
    qt6.qtwayland
    shared-mime-info
    dconf
    glib
    gnome-keyring
  ];
}
