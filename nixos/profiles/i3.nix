{ pkgs, ... }:

{
  services.xserver.enable = true;
  services.xserver.windowManager.i3 = {
    enable = true;
    extraPackages = with pkgs; [ i3status ];
  };

  security.polkit.enable = true;
  services.dbus.enable = true;
  services.gvfs.enable = true;
  services.gnome.gnome-keyring.enable = true;
  programs.dconf.enable = true;
  programs.nautilus-open-any-terminal = {
    enable = true;
    terminal = "kitty";
  };

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ];
    config.common.default = [ "gtk" ];
  };

  environment.systemPackages = with pkgs; [
    i3
    i3lock-color
    polybar
    picom

    rofi
    dunst

    xdg-utils
    xdg-desktop-portal
    xdg-desktop-portal-gtk

    xwinwrap
    mpv
    ffmpeg

    kitty
    chromium
    nautilus
    stow

    networkmanagerapplet
    blueman
    pavucontrol

    polkit_gnome
    gnome-keyring
    dex
    xss-lock

    flameshot
    brightnessctl
    pamixer
    playerctl

    xclip
    xorg.xset
    xorg.xsetroot
    xorg.setxkbmap
  ];
}
