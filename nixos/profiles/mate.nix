{ pkgs, ... }:

{
  imports = [ ./sddm.nix ./printer.nix ];

  services.xserver.enable = true;
  services.xserver.desktopManager.mate.enable = true;
  services.displayManager.defaultSession = "mate";

  services.libinput.enable = true;
  security.polkit.enable = true;
  services.dbus.enable = true;
  services.gvfs.enable = true;
  services.udisks2.enable = true;
  services.gnome.gnome-keyring.enable = true;
  services.power-profiles-daemon.enable = true;

  programs.dconf.enable = true;
  security.pam.services.sddm.enableGnomeKeyring = true;
  security.pam.services.login.enableGnomeKeyring = true;

  services.pulseaudio.enable = false;

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = [ "gtk" ];
  };

  xdg.mime = {
    enable = true;
    defaultApplications = {
      "inode/directory" = [ "caja.desktop" ];
      "text/plain" = [ "pluma.desktop" ];
      "text/markdown" = [ "pluma.desktop" ];
      "text/x-markdown" = [ "pluma.desktop" ];
      "application/pdf" = [ "atril.desktop" ];
      "image/png" = [ "eom.desktop" ];
      "image/jpeg" = [ "eom.desktop" ];
      "image/webp" = [ "eom.desktop" ];
      "image/gif" = [ "eom.desktop" ];
      "video/mp4" = [ "io.github.celluloid_player.Celluloid.desktop" ];
      "video/x-matroska" = [ "io.github.celluloid_player.Celluloid.desktop" ];
      "video/webm" = [ "io.github.celluloid_player.Celluloid.desktop" ];
      "video/x-msvideo" = [ "io.github.celluloid_player.Celluloid.desktop" ];
      "application/zip" = [ "engrampa.desktop" ];
      "application/x-tar" = [ "engrampa.desktop" ];
      "application/x-7z-compressed" = [ "engrampa.desktop" ];
      "application/x-rar" = [ "engrampa.desktop" ];
      "text/html" = [ "chromium.desktop" ];
      "application/xhtml+xml" = [ "chromium.desktop" ];
      "x-scheme-handler/http" = [ "chromium.desktop" ];
      "x-scheme-handler/https" = [ "chromium.desktop" ];
    };
  };

  environment.systemPackages = with pkgs; [
    # MATE extras (core installed by desktopManager.mate)
    mate-applets
    mate-icon-theme-faenza

    # Keyring plumbing
    gcr
    gnome-keyring
    gsettings-desktop-schemas

    # XDG portal
    xdg-utils
    xdg-desktop-portal
    xdg-desktop-portal-gtk

    # Themes — pre-installed, user selects via MATE Appearance
    arc-theme
    arc-icon-theme
    papirus-icon-theme
    adwaita-icon-theme
    materia-theme
    numix-cursor-theme
    yaru-remix-theme
  ] ++ (with pkgs; [
    # Explicitly enumerate former mate package set extras, now removed upstream.
    atril
    caja-extensions
    eom
    engrampa
    mate-backgrounds
    mate-calc
    mate-indicator-applet
    mate-media
    mate-netbook
    mate-power-manager
    mate-screensaver
    mate-system-monitor
    mate-terminal
    mate-user-guide
    mate-utils
    mozo
    pluma
  ]);
}
