{
  config,
  pkgs,
  lib,
  userName ? "osmarg",
  ...
}:

let
  sddmKwinOutputConfig = ../hosts/${config.networking.hostName}/sddm-kwinoutputconfig.json;
  hasSddmKwinOutputConfig = builtins.pathExists sddmKwinOutputConfig;
in
{
  imports = [
    ./sddm.nix
    ./printer.nix
    ./vesktop.nix
  ];

  services.xserver.enable = false;
  services.displayManager.defaultSession = "hyprland";

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
    package = pkgs.hyprland;
    portalPackage = pkgs.xdg-desktop-portal-hyprland;
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
  services.gnome.gnome-online-accounts.enable = true;

  services.dbus.enable = true;
  services.udisks2.enable = true;
  services.gvfs.enable = true;
  services.gvfs.package = pkgs.gnome.gvfs.override {
    gnomeSupport = true;
  };
  nixpkgs.config.permittedInsecurePackages = [ "libsoup-2.74.3" ];
  services.gnome.gnome-keyring.enable = true;
  programs.dconf.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
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
    # Native NixOS Hyprland stack. This avoids a flake-pinned compositor build.
    hyprland
    xwayland
    hyprpaper
    hyprpolkitagent

    # Portal / XDG
    xdg-utils
    desktop-file-utils
    xdg-desktop-portal
    xdg-desktop-portal-hyprland
    xdg-desktop-portal-gtk

    # Clipboard / screenshots / wlroots-compatible tools
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

    # GNOME apps used as defaults
    # Uso esporádico via `, app` (nix run): apostrophe, totem, baobab,
    # gnome-disk-utility, gnome-logs, seahorse, gnome-font-viewer,
    # gnome-characters, warehouse, gnome-tweaks, overskride, iwgtk
    nautilus
    gnome-online-accounts-gtk
    gnome-text-editor
    loupe
    evince
    mpv
    file-roller
    gnome-calculator
    gnome-system-monitor
    sushi
    gnome-software

    # Desktop integration / theming
    gsettings-desktop-schemas
    adwaita-icon-theme
    hicolor-icon-theme
    gnome-themes-extra
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

  assertions = [
    {
      assertion = lib.versionAtLeast pkgs.hyprland.version "0.55.1";
      message = "The native nixpkgs Hyprland package must be newer than 0.55.";
    }
  ];
}
