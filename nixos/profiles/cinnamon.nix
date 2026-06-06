{ pkgs, lib, ... }:

{
  services.xserver.enable = true;

  # Force Cinnamon-only desktop stack.
  services.desktopManager.gnome.enable = lib.mkForce false;
  services.displayManager.defaultSession = lib.mkForce "cinnamon";
  services.displayManager.gdm.enable = lib.mkForce false;
  # Cinnamon as desktop environment.
  services.xserver.desktopManager.cinnamon.enable = true;
  services.cinnamon.apps.enable = true;
  services.xserver.displayManager = {
    lightdm = {
      enable = true;
      greeter = {
        package = pkgs.lightdm-slick-greeter;
        name = "slick-greeter";
      };
    };
  };

  services.libinput.enable = true;
  services.dbus.enable = true;
  services.gvfs.enable = true;
  services.udisks2.enable = true;
  services.power-profiles-daemon.enable = true;
  services.gnome = {
    gnome-keyring.enable = true;
    gnome-online-accounts.enable = true;
    gcr-ssh-agent.enable = true;
  };

  services.pulseaudio.enable = false;

  programs.dconf.enable = true;
  security.pam.services.lightdm.enableGnomeKeyring = true;
  security.pam.services.login.enableGnomeKeyring = true;
  security.polkit.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-xapp
      xdg-desktop-portal-gtk
    ];
    config = {
      common.default = [
        "xapp"
        "gtk"
      ];
    };
    configPackages = [ pkgs.cinnamon ];
  };

  xdg.terminal-exec = {
    enable = true;
    settings = {
      cinnamon = [ "kitty.desktop" ];
      default = [ "kitty.desktop" ];
    };
  };

  xdg.mime = {
    enable = true;
    defaultApplications = {
      "inode/directory" = [ "nemo.desktop" ];
      "text/plain" = [ "xed.desktop" ];
      "text/markdown" = [ "xed.desktop" ];
      "text/x-markdown" = [ "xed.desktop" ];
      "application/pdf" = [ "xreader.desktop" ];
      "image/png" = [ "xviewer.desktop" ];
      "image/jpeg" = [ "xviewer.desktop" ];
      "image/webp" = [ "xviewer.desktop" ];
      "image/gif" = [ "xviewer.desktop" ];
      "video/mp4" = [ "io.github.celluloid_player.Celluloid.desktop" ];
      "video/x-matroska" = [ "io.github.celluloid_player.Celluloid.desktop" ];
      "video/webm" = [ "io.github.celluloid_player.Celluloid.desktop" ];
      "video/x-msvideo" = [ "io.github.celluloid_player.Celluloid.desktop" ];
      "application/zip" = [ "org.gnome.FileRoller.desktop" ];
      "application/x-tar" = [ "org.gnome.FileRoller.desktop" ];
      "application/x-7z-compressed" = [ "org.gnome.FileRoller.desktop" ];
      "application/x-rar" = [ "org.gnome.FileRoller.desktop" ];
      "text/html" = [ "chromium.desktop" ];
      "application/xhtml+xml" = [ "chromium.desktop" ];
      "x-scheme-handler/http" = [ "chromium.desktop" ];
      "x-scheme-handler/https" = [ "chromium.desktop" ];
    };
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
    GDK_BACKEND = "wayland,x11";
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
    TERMINAL = "kitty";
  };

  environment.systemPackages = with pkgs; [
    # Cinnamon core.
    cinnamon
    nemo
    xed
    xreader
    xviewer
    celluloid
    file-roller

    # Gnome-keyring / desktop plumbing.
    gcr
    gnome-keyring
    gsettings-desktop-schemas

    # XDG portal + desktop integration.
    xdg-utils
    xdg-desktop-portal
    xdg-desktop-portal-xapp
    xdg-desktop-portal-gtk
  ];
}
