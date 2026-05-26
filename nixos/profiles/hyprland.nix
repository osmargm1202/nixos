{ pkgs, lib, inputs, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;
  hyprlandPkgs = inputs.hyprland.packages.${system};
  hyprpaperPkg = inputs.hyprpaper.packages.${system}.hyprpaper;
  nwgDockHyprlandGit = pkgs.nwg-dock-hyprland.overrideAttrs (old: {
    version = "git-${inputs.nwg-dock-hyprland-src.shortRev or "unknown"}";
    src = inputs.nwg-dock-hyprland-src;
    vendorHash = "sha256-AJGyBCTWtgTpn+e4HLlX/8EgWITw25py4UJJJDLhoOM=";
  });
  orgmHypr = pkgs.callPackage ../packages/orgm-hypr.nix { };
in
{
  imports = [
    inputs.ltmnight-sddm-theme.nixosModules.default
  ];

  # Hyprland through SDDM with the LTMNight theme.
  services.xserver.enable = false;
  services.displayManager = {
    defaultSession = "hyprland";
    sddm = {
      enable = true;
      wayland.enable = true;
      autoNumlock = true;
      enableHidpi = true;
      theme = "ltmnight";
      settings.General = {
        InputMethod = "qtvirtualkeyboard";
        Numlock = "on";
      };
    };
  };

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

  services.dbus.enable = true;
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

  xdg.mime = {
    enable = true;
    defaultApplications = {
      "inode/directory" = [ "org.gnome.Nautilus.desktop" ];
      "text/plain" = [ "org.gnome.TextEditor.desktop" ];
      "text/markdown" = [ "org.gnome.TextEditor.desktop" ];
      "text/x-markdown" = [ "org.gnome.TextEditor.desktop" ];
      "text/html" = [ "chromium-browser.desktop" "chromium.desktop" ];
      "application/xhtml+xml" = [ "chromium-browser.desktop" "chromium.desktop" ];
      "x-scheme-handler/http" = [ "chromium-browser.desktop" "chromium.desktop" ];
      "x-scheme-handler/https" = [ "chromium-browser.desktop" "chromium.desktop" ];
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
    quickshell
    orgmHypr
    # Google Calendar support: gcalcli is a Python application and may pull
    # Python via Nix. python3Minimal below was pre-existing; the Go helper does
    # not add or require extra Python packages.
    gcalcli
    libnotify
    ffmpeg
    python3Minimal
    hypridle
    hyprlock
    hyprpicker
    hyprsunset
    hyprpolkitagent

    # Shell / panel for Hyprland.
    waybar
    nwgDockHyprlandGit
    nwg-drawer
    nwg-displays
    nwg-look

    # Shell / launchers / terminal
    kitty
    fuzzel
    rofi
    libqalculate
    yad
    wlogout
    swaynotificationcenter

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
    pamixer
    playerctl
    pavucontrol
    networkmanagerapplet
    bluetui
    blueman
    dunst
    overskride
    iwgtk

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
