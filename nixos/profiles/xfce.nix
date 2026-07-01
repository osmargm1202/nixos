{ pkgs, ... }:

{
  imports = [ ./printer.nix ];

  services.xserver.enable = true;
  services.xserver.desktopManager.xfce.enable = true;
  services.displayManager.defaultSession = "xfce";
  services.displayManager.sddm.enable = true;

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
      "inode/directory" = [ "thunar.desktop" ];
      "text/plain" = [ "mousepad.desktop" ];
      "text/markdown" = [ "mousepad.desktop" ];
      "text/x-markdown" = [ "mousepad.desktop" ];
      "application/pdf" = [ "evince.desktop" ];
      "image/png" = [ "ristretto.desktop" ];
      "image/jpeg" = [ "ristretto.desktop" ];
      "image/webp" = [ "ristretto.desktop" ];
      "image/gif" = [ "ristretto.desktop" ];
      "video/mp4" = [ "io.github.celluloid_player.Celluloid.desktop" ];
      "video/x-matroska" = [ "io.github.celluloid_player.Celluloid.desktop" ];
      "video/webm" = [ "io.github.celluloid_player.Celluloid.desktop" ];
      "video/x-msvideo" = [ "io.github.celluloid_player.Celluloid.desktop" ];
      "application/zip" = [ "xarchiver.desktop" ];
      "application/x-tar" = [ "xarchiver.desktop" ];
      "application/x-7z-compressed" = [ "xarchiver.desktop" ];
      "application/x-rar" = [ "xarchiver.desktop" ];
      "text/html" = [ "chromium.desktop" ];
      "application/xhtml+xml" = [ "chromium.desktop" ];
      "x-scheme-handler/http" = [ "chromium.desktop" ];
      "x-scheme-handler/https" = [ "chromium.desktop" ];
    };
  };

  environment.systemPackages = with pkgs; [
    # XFCE extras (core installed by desktopManager.xfce)
    xfce.xfce4-pulseaudio-plugin
    xfce.xfce4-whiskermenu-plugin
    xfce.thunar-volman
    xfce.thunar-archive-plugin
    xfce.thunar-media-tags-plugin
    xarchiver
    evince

    # Keyring plumbing
    gcr
    gnome-keyring
    gsettings-desktop-schemas

    # XDG portal
    xdg-utils
    xdg-desktop-portal
    xdg-desktop-portal-gtk

    # Themes — pre-installed, user selects via xfce4-appearance-manager
    arc-theme
    arc-icon-theme
    papirus-icon-theme
    adwaita-icon-theme
    materia-theme
    numix-cursor-theme
    yaru-remix-theme
  ];
}
