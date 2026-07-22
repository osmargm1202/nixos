{
  pkgs,
  lib,
  inputs,
  userName ? "osmarg",
  ...
}:

let
  i3expo = pkgs.callPackage ../packages/i3expo-ng.nix { };
  i3CleanIconset = ../../dotfiles/config/profiles/i3/.config/bumblebee-status/themes/icons/i3-clean.json;
  bumblebeeI3 = (pkgs.bumblebee-status.override {
    plugins = p: [ p.shortcut p.date p.time ];
  }).overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      install -Dm644 ${i3CleanIconset} \
        "$out/${pkgs.python3.sitePackages}/themes/icons/i3-clean.json"
    '';
  });
  # Expose only a uniquely named fallback; installing i3lock-color directly
  # would collide with i3lock-fancy's bin/i3lock symlink.
  i3lockColorFallback = pkgs.writeShellApplication {
    name = "i3lock-color-fallback";
    text = ''
      exec ${lib.getExe' pkgs.i3lock-color "i3lock-color"} "$@"
    '';
  };
  zenBrowser = pkgs.callPackage ../packages/zen-browser.nix {
    zenBrowserFlakeSrc = inputs.zen-browser-flake;
  };
in
{
  imports = [
    ./printer.nix
    ./vesktop.nix
  ];

  services.xserver = {
    enable = true;
    displayManager.startx = {
      enable = true;
      generateScript = true;
    };
    windowManager.i3 = {
      enable = true;
      extraPackages = [ bumblebeeI3 ];
    };
  };
  services.displayManager.defaultSession = "none+i3";

  services.autorandr = {
    enable = true;
    defaultTarget = "horizontal";
    matchEdid = true;
  };

  # Password-authenticated tty1 login unlocks GNOME Keyring through PAM before X starts.
  programs.fish.loginShellInit = lib.mkAfter ''
    if test (tty) = /dev/tty1; and not set -q DISPLAY
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
  services.upower = {
    enable = true;
    package = pkgs.upower;
  };
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
      "video/mp4" = [ "org.videolan.VLC.desktop" ];
      "video/x-matroska" = [ "org.videolan.VLC.desktop" ];
      "video/webm" = [ "org.videolan.VLC.desktop" ];
      "video/quicktime" = [ "org.videolan.VLC.desktop" ];
      "video/x-msvideo" = [ "org.videolan.VLC.desktop" ];
      "video/mpeg" = [ "org.videolan.VLC.desktop" ];
      "video/ogg" = [ "org.videolan.VLC.desktop" ];
      "text/html" = [ "zen-browser.desktop" ];
      "application/xhtml+xml" = [ "zen-browser.desktop" ];
      "x-scheme-handler/http" = [ "zen-browser.desktop" ];
      "x-scheme-handler/https" = [ "zen-browser.desktop" ];
    };
  };

  environment.localBinInPath = true;

  environment.sessionVariables = {
    XDG_SESSION_TYPE = "x11";
    XDG_SESSION_DESKTOP = "i3";
    XDG_CURRENT_DESKTOP = "i3";
    TERMINAL = "kitty";
  };

  environment.systemPackages = with pkgs; [
    # Xorg session and window manager.
    xorg-server
    xinit
    xauth
    xrdb
    xrandr
    xinput
    xset
    xsetroot
    setxkbmap
    xkill
    i3
    i3expo
    (i3lock-fancy.override {
      screenshotCommand = "${scrot}/bin/scrot -z -o";
    })
    i3lockColorFallback

    # Launchers, notifications, wallpaper and X11 helpers.
    (rofi.override { plugins = [ rofi-calc ]; })
    clipmenu
    dunst
    feh
    arandr
    xclip
    xkb-switch

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
    pasystray
    polkit_gnome
    gnome-keyring
    dex
    xss-lock
    udiskie
    usbutils

    # User controls and X11 screen recording.
    flameshot
    ffcast
    imagemagick
    brightnessctl
    pamixer
    playerctl

    # Runtime-selected GTK/Nautilus appearance.
    adwaita-icon-theme
    hicolor-icon-theme
    colloid-icon-theme
    catppuccin-gtk
    catppuccin-cursors.macchiatoTeal
    catppuccin-cursors.latteTeal
    gnome-themes-extra

    # Daily applications used by MIME defaults and bindings.
    kitty
    chromium
    zenBrowser
    nautilus
    gnome-online-accounts-gtk
    gnome-text-editor
    evince
    loupe
    file-roller
  ];
}
