{ pkgs, lib, ... }:

{
  # Sway sin display manager: login en tty1 y arranque automático.
  # Sin autologin, PAM puede desbloquear GNOME Keyring con la clave de login.
  services.xserver.enable = false;

  programs.fish.loginShellInit = ''
    if test -z "$DISPLAY"; and test -z "$WAYLAND_DISPLAY"; and test (tty) = "/dev/tty1"
      exec sway
    end
  '';

  programs.sway = {
    enable = true;
    package = pkgs.swayfx;
    xwayland.enable = true;
    wrapperFeatures.gtk = true;
  };
  programs.xwayland.enable = true;

  programs.nautilus-open-any-terminal = {
    enable = true;
    terminal = "kitty";
  };

  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-wlr
      xdg-desktop-portal-gtk
    ];
    config = {
      common.default = [
        "wlr"
        "gtk"
      ];
      wlroots.default = [
        "wlr"
        "gtk"
      ];
      sway = {
        default = lib.mkForce [
          "wlr"
          "gtk"
        ];
        "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
        "org.freedesktop.impl.portal.OpenURI" = [ "gtk" ];
        "org.freedesktop.impl.portal.ScreenCast" = [ "wlr" ];
        "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
      };
    };
  };

  xdg.terminal-exec = {
    enable = true;
    settings = {
      sway = [ "kitty.desktop" ];
      default = [ "kitty.desktop" ];
    };
  };

  # Programas por defecto: GNOME apps + Chromium para HTML/web.
  xdg.mime = {
    enable = true;
    defaultApplications = {
      "inode/directory" = [ "org.gnome.Nautilus.desktop" ];

      # Texto / Markdown
      "text/plain" = [ "org.gnome.TextEditor.desktop" ];
      "text/markdown" = [ "org.gnome.TextEditor.desktop" ];
      "text/x-markdown" = [ "org.gnome.TextEditor.desktop" ];

      # HTML / Web
      "text/html" = [ "chromium-browser.desktop" "chromium.desktop" ];
      "application/xhtml+xml" = [ "chromium-browser.desktop" "chromium.desktop" ];
      "x-scheme-handler/http" = [ "chromium-browser.desktop" "chromium.desktop" ];
      "x-scheme-handler/https" = [ "chromium-browser.desktop" "chromium.desktop" ];

      # PDF
      "application/pdf" = [ "org.gnome.Evince.desktop" ];

      # Imágenes
      "image/png" = [ "org.gnome.Loupe.desktop" ];
      "image/jpeg" = [ "org.gnome.Loupe.desktop" ];
      "image/webp" = [ "org.gnome.Loupe.desktop" ];
      "image/gif" = [ "org.gnome.Loupe.desktop" ];
      "image/svg+xml" = [ "org.gnome.Loupe.desktop" ];

      # Videos / audio
      "video/mp4" = [ "org.gnome.Totem.desktop" "mpv.desktop" ];
      "video/x-matroska" = [ "org.gnome.Totem.desktop" "mpv.desktop" ];
      "video/webm" = [ "org.gnome.Totem.desktop" "mpv.desktop" ];
      "audio/mpeg" = [ "org.gnome.Totem.desktop" "mpv.desktop" ];
      "audio/flac" = [ "org.gnome.Totem.desktop" "mpv.desktop" ];
      "audio/ogg" = [ "org.gnome.Totem.desktop" "mpv.desktop" ];

      # Comprimidos
      "application/zip" = [ "org.gnome.FileRoller.desktop" ];
      "application/x-tar" = [ "org.gnome.FileRoller.desktop" ];
      "application/x-7z-compressed" = [ "org.gnome.FileRoller.desktop" ];
      "application/x-rar" = [ "org.gnome.FileRoller.desktop" ];
    };
  };

  security.polkit = {
    enable = true;
    # Evita prompts repetidos de polkit al abrir navegadores en Sway
    # por acciones de colord/color-manager.
    extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (subject.user == "osmarg" && action.id.indexOf("org.freedesktop.color-manager.") == 0) {
          return polkit.Result.YES;
        }
      });
    '';
  };
  security.pam.services.login.enableGnomeKeyring = true;

  services.dbus.enable = true;
  services.gvfs.enable = true;
  services.gnome.gnome-keyring.enable = true;
  programs.dconf.enable = true;

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
    XDG_SESSION_TYPE = "wayland";
    XDG_SESSION_DESKTOP = "sway";
    XDG_CURRENT_DESKTOP = "sway:wlroots";
    QT_QPA_PLATFORM = "wayland";
    QT_QPA_PLATFORMTHEME = "qt5ct";
    QT_QPA_PLATFORMTHEME_QT6 = "qt6ct";
    QT_STYLE_OVERRIDE = "kvantum";
    GTK_THEME = "catppuccin-macchiato-teal-standard";
    XCURSOR_THEME = "Catppuccin-Macchiato-Teal-Cursors";
    XCURSOR_SIZE = "24";
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
    GDK_BACKEND = "wayland,x11";
    SDL_VIDEODRIVER = "wayland";
    CLUTTER_BACKEND = "wayland";
    TERMINAL = "kitty";
  };

  environment.systemPackages = with pkgs; [
    swayfx
    xwayland

    # Shell Sway
    waybar
    yad
    swaybg
    swayidle
    swaylock-effects
    swaynotificationcenter
    wlogout
    fuzzel
    kitty

    # Portal / XDG
    xdg-utils
    xdg-desktop-portal
    xdg-desktop-portal-wlr
    xdg-desktop-portal-gtk

    # Clipboard / screenshots / wlroots tools
    wl-clipboard
    cliphist
    grim
    slurp
    swappy
    wlr-randr
    wlrctl
    wtype
    wlopm

    # Hardware controls
    brightnessctl
    pamixer
    playerctl
    pavucontrol
    networkmanagerapplet
    blueman
    wdisplays
    wl-screenrec
    dunst
    overskride
    iwgtk

    # GNOME apps usados como defaults
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
    gnome-software
    seahorse
    gnome-font-viewer
    gnome-characters
    sushi

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
    kdePackages.qtstyleplugin-kvantum
    qt6Packages.qt6ct
    shared-mime-info
    dconf
    glib
    gnome-keyring
    polkit_gnome
  ];
}
