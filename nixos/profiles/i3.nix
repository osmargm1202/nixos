{
  pkgs,
  lib,
  ...
}:

let
  ngcbgI3Tools = pkgs.callPackage ../packages/ngcbg-i3-tools.nix { };
  thunarWithoutWallpaperPlugin = pkgs.thunar.overrideAttrs (old: {
    postFixup = (old.postFixup or "") + ''
      rm -f "$out/lib/thunarx-3/thunar-wallpaper-plugin.so" \
        "$out/lib/thunarx-3/thunar-wallpaper-plugin.la"
    '';
  });
in
{
  imports = [
    ./sddm.nix
    ./printer.nix
    ./vesktop.nix
  ];

  services.xserver = {
    enable = true;
    windowManager.i3.enable = true;
  };
  services.displayManager.defaultSession = "none+i3";

  # i3 is an X11 session. The KWin Wayland greeter exits immediately on this
  # hardware, leaving SDDM running without a visible login screen.
  services.displayManager.sddm.wayland.enable = lib.mkForce false;

  # i3 is selected explicitly from SDDM; never sign in automatically.
  services.displayManager.autoLogin.enable = lib.mkForce false;

  # A manual i3 session must remain usable when the lid is closed. Logind
  # cannot scope lid handling to a VT, so disable lid-initiated suspend for
  # this profile entirely; idle time remains ignored as before.
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
    IdleAction = "ignore";
  };
  services.autorandr = {
    enable = true;
    defaultTarget = "horizontal";
    matchEdid = true;
  };

  systemd.user.services.i3-clipcat = {
    description = "Clipcat clipboard history for i3";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${lib.getExe' pkgs.clipcat "clipcatd"} --no-daemon --config %h/.config/clipcat/clipcatd.toml --grpc-socket-path %t/clipcat/grpc.sock --history-file %t/clipcat/history";
      Restart = "on-failure";
      RestartSec = 3;
    };
  };

  services.libinput.enable = true;
  security.polkit.enable = true;
  services.dbus.enable = true;
  services.udisks2.enable = true;
  services.upower = {
    enable = true;
    package = pkgs.upower;
  };
  services.gnome = {
    gnome-keyring.enable = true;
    gnome-online-accounts.enable = true;
  };
  services.power-profiles-daemon.enable = true;
  nixpkgs.config.permittedInsecurePackages = [ "libsoup-2.74.3" ];

  programs.dconf.enable = true;
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
      "inode/directory" = [ "thunar.desktop" ];
      "text/plain" = [ "org.gnome.TextEditor.desktop" ];
      "text/markdown" = [ "org.gnome.TextEditor.desktop" ];
      "text/x-markdown" = [ "org.gnome.TextEditor.desktop" ];
      "application/pdf" = [ "org.gnome.Evince.desktop" ];
      "image/png" = [ "org.gnome.Loupe.desktop" ];
      "image/jpeg" = [ "org.gnome.Loupe.desktop" ];
      "image/webp" = [ "org.gnome.Loupe.desktop" ];
      "image/gif" = [ "org.gnome.Loupe.desktop" ];
      "image/svg+xml" = [ "org.gnome.Loupe.desktop" ];
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
    };
  };

  environment.localBinInPath = true;

  environment.sessionVariables = {
    XDG_SESSION_TYPE = "x11";
    XDG_SESSION_DESKTOP = "i3";
    XDG_CURRENT_DESKTOP = "i3";
    XCURSOR_SIZE = "24";
    TERMINAL = "kitty";
  };

  environment.systemPackages = (
    with pkgs;
    [
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
      i3status
      clipcat
      yazi
      ueberzugpp
      ffmpegthumbnailer
      mediainfo
      poppler-utils
      fontconfig
      git
      gnused
      iproute2
      procps
      i3lock-color
      ngcbgI3Tools.autotiling
      ngcbgI3Tools.rootbtnd
      ngcbgI3Tools.i3swallow
      ngcbgI3Tools.xlogout

      # Launchers, notifications, wallpaper and X11 helpers.
      (rofi.override { plugins = [ rofi-calc ]; })
      networkmanager_dmenu
      # Clipboard history is supplied by the persistent Clipcat user service.
      dunst
      feh
      mpv
      xwinwrap
      arandr
      xdotool
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
      dex
      xss-lock
      udiskie
      usbutils

      # User controls and X11 screen recording.
      flameshot
      ffcast
      ffmpeg
      brightnessctl
      pamixer
      playerctl

      # Runtime-selected GTK appearance and status interactions.
      gsimplecal
      lm_sensors
      lxappearance
      adwaita-icon-theme
      hicolor-icon-theme
      colloid-icon-theme
      catppuccin-gtk
      catppuccin-cursors.macchiatoTeal
      catppuccin-cursors.latteTeal
      gnome-themes-extra

      # Daily applications used by MIME defaults and bindings.
      kitty
      thunarWithoutWallpaperPlugin
      tumbler
      gnome-text-editor
      evince
      loupe
      file-roller
      pkgs.gnome-keyring
      pkgs."gnome-online-accounts-gtk"
    ]
  );
}
