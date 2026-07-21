{
  pkgs,
  lib,
  userName ? "osmarg",
  ...
}:

{
  imports = [ ./printer.nix ];

  services.xserver = {
    enable = true;
    displayManager.startx = {
      enable = true;
      generateScript = true;
    };
    windowManager.i3 = {
      enable = true;
      extraPackages = with pkgs; [ i3status ];
    };
  };
  services.displayManager.defaultSession = "none+i3";
  services.getty.autologinUser = userName;

  programs.fish.loginShellInit = lib.mkAfter ''
    set -l i3_startx_marker "/run/user/"(id -u)"/i3-startx-attempted"
    if test (tty) = /dev/tty1; and not set -q DISPLAY; and not test -e "$i3_startx_marker"
      touch "$i3_startx_marker"
      exec startx /etc/X11/xinit/xinitrc
    end
  '';

  services.libinput.enable = true;
  security.polkit.enable = true;
  services.dbus.enable = true;
  services.gvfs.enable = true;
  services.gvfs.package = pkgs.gnome.gvfs.override {
    gnomeSupport = true;
  };
  services.udisks2.enable = true;
  services.upower.enable = true;
  services.gnome.gnome-keyring.enable = true;
  services.gnome.gnome-online-accounts.enable = true;
  services.power-profiles-daemon.enable = true;
  nixpkgs.config.permittedInsecurePackages = [ "libsoup-2.74.3" ];

  programs.dconf.enable = true;
  security.pam.services.login.enableGnomeKeyring = true;
  programs.nautilus-open-any-terminal = {
    enable = true;
    terminal = "kitty";
  };

  services.pulseaudio.enable = false;

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config = {
      common.default = [ "gtk" ];
      i3.default = [ "gtk" ];
    };
  };

  xdg.terminal-exec = {
    enable = true;
    settings = {
      i3 = [ "kitty.desktop" ];
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
      "application/pdf" = [ "org.gnome.Evince.desktop" ];
      "image/png" = [ "org.gnome.Loupe.desktop" ];
      "image/jpeg" = [ "org.gnome.Loupe.desktop" ];
      "image/webp" = [ "org.gnome.Loupe.desktop" ];
      "image/gif" = [ "org.gnome.Loupe.desktop" ];
      "application/zip" = [ "org.gnome.FileRoller.desktop" ];
      "application/x-tar" = [ "org.gnome.FileRoller.desktop" ];
      "application/x-7z-compressed" = [ "org.gnome.FileRoller.desktop" ];
      "text/html" = [ "chromium.desktop" ];
      "application/xhtml+xml" = [ "chromium.desktop" ];
      "x-scheme-handler/http" = [ "chromium.desktop" ];
      "x-scheme-handler/https" = [ "chromium.desktop" ];
    };
  };

  environment.sessionVariables = {
    XDG_SESSION_TYPE = "x11";
    XDG_SESSION_DESKTOP = "i3";
    XDG_CURRENT_DESKTOP = "i3";
    TERMINAL = "kitty";
  };

  environment.systemPackages = with pkgs; [
    # Xorg session and window manager.
    xorg.xorgserver
    xorg.xinit
    xorg.xauth
    xorg.xrdb
    xorg.xrandr
    xorg.xinput
    xorg.xset
    xorg.xsetroot
    xorg.setxkbmap
    xorg.xkill
    i3
    i3lock-color
    polybar
    picom

    # Launchers, notifications, wallpaper and X11 helpers.
    rofi
    rofi-calc
    clipmenu
    dunst
    feh
    arandr
    xclip

    # Desktop integration.
    xdg-utils
    desktop-file-utils
    xdg-desktop-portal
    xdg-desktop-portal-gtk
    shared-mime-info
    stow

    networkmanagerapplet
    blueman
    pavucontrol
    polkit_gnome
    gnome-keyring
    dex
    xss-lock
    udiskie
    usbutils

    # User controls.
    flameshot
    brightnessctl
    pamixer
    playerctl

    # Daily applications used by MIME defaults and bindings.
    kitty
    chromium
    nautilus
    gnome-online-accounts-gtk
    gnome-text-editor
    evince
    loupe
    file-roller
  ];
}
