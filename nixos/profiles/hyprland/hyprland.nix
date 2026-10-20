{
  config,
  lib,
  pkgs,
  userName ? "osmarg",
  ...
}:
let
  # Use NixOS's released package set and its binary cache, without source overrides.
  hyprlandPackage = pkgs.hyprland;
  hyprlandPortalPackage = pkgs.xdg-desktop-portal-hyprland;
  hyprKdeconnectFix = pkgs.callPackage ./hypr-kdeconnect-fix.nix { };
  dockPackage = import ./nwg-dock.nix { inherit pkgs; };
  waybarPackage = import ./waybar.nix { inherit pkgs; };
in
{
  imports = [
    ../../sddm/sddm.nix
    ../../print/printer.nix
    ./desktop-session.nix
  ];
  services.xserver.enable = false;
  services.displayManager.defaultSession = "hyprland";

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    package = hyprlandPackage;
    portalPackage = hyprlandPortalPackage;
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
  security.pam.services.login.enableGnomeKeyring = true;

  programs.nautilus-open-any-terminal = {
    enable = true;
    terminal = "kitty";
  };

  services.power-profiles-daemon.enable = true;
  services.gnome.gnome-online-accounts.enable = true;

  services.dbus.enable = true;
  nixpkgs.config.permittedInsecurePackages = [ "libsoup-2.74.3" ];
  services.gnome.gnome-keyring.enable = true;
  programs.dconf.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      hyprKdeconnectFix
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
      hyprland."org.freedesktop.impl.portal.RemoteDesktop" = "hypr-kdeconnect";
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
      dconf.settings = lib.mkIf (config.networking.hostName == "orgm") {
        "org/gnome/desktop/interface" = {
          font-name = "Sans 11";
          text-scaling-factor = 1.0;
        };
      };

      home.activation.mimeAppsDefaults = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        mime_cfg="$HOME/.config/mimeapps.list"
        if [ ! -f "$mime_cfg" ]; then
          $DRY_RUN_CMD mkdir -p "$(dirname "$mime_cfg")"
          $DRY_RUN_CMD cp ${mimeAppsDefaults} "$mime_cfg"
        fi
        $DRY_RUN_CMD ${pkgs.xdg-utils}/bin/xdg-mime default org.gnome.Nautilus.desktop inode/directory
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
    CLUTTER_BACKEND = "wayland";
    TERMINAL = "kitty";
  };

  # The TCL Roku TV uses Miracast over Infrastructure Connection
  # Establishment (MICE); it connects to GND's fixed RTSP listener on 7236.
  networking.firewall.allowedTCPPorts = [ 7236 ];

  environment.systemPackages = with pkgs; [
    # Released compositor and matching portal from the selected NixOS channel.
    hyprlandPackage
    xwayland
    hyprpaper
    mpvpaper
    hyprpolkitagent

    # Portal / XDG
    xdg-utils
    desktop-file-utils
    xdg-desktop-portal
    hyprlandPortalPackage
    xdg-desktop-portal-gtk

    # Clipboard / screenshots / wlroots-compatible tools
    cliphist
    grim
    slurp
    swappy
    wl-screenrec
    wtype
    woomer

    # Hardware controls
    brightnessctl
    pamixer
    playerctl
    pavucontrol
    pasystray
    nwg-look

    # GNOME apps used as defaults
    # Uso esporádico via `, app` (nix run): apostrophe, baobab,
    # gnome-disk-utility, gnome-logs, seahorse, gnome-font-viewer,
    # gnome-characters, warehouse, gnome-tweaks, overskride, iwgtk
    nautilus
    totem
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
    gnome-network-displays

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
    hyprlock
    hypridle
    (rofi.override { plugins = [ rofi-calc ]; })
    rofimoji
    libqalculate
    bluetui
    blueman
    networkmanagerapplet
    nwg-displays
    dockPackage
    pulsemixer
    waybarPackage
  ];

  security.pam.services.hyprlock = { };

}
