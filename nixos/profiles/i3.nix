{
  pkgs,
  lib,
  inputs,
  userName ? "osmarg",
  ...
}:

let
  i3expo = pkgs.callPackage ../packages/i3expo-ng.nix { };
  # Expose only a uniquely named fallback; installing i3lock-color directly
  # would collide with i3lock-fancy's bin/i3lock symlink.
  i3lockColorFallback = pkgs.writeShellApplication {
    name = "i3lock-color-fallback";
    text = ''
      exec ${lib.getExe' pkgs.i3lock-color "i3lock-color"} "$@"
    '';
  };
  # The pinned NixOS Picom module serializes every list with square brackets,
  # but libconfig requires parentheses for lists of rule/animation groups.
  # Generate the native config directly until that module formatter is fixed.
  picomConfig = pkgs.writeText "picom-i3.conf" ''
    backend = "glx";
    vsync = true;
    use-damage = true;
    detect-rounded-corners = true;
    detect-client-opacity = true;
    detect-transient = true;
    transparent-clipping = false;

    fading = true;
    fade-delta = 5;
    fade-in-step = 0.045;
    fade-out-step = 0.045;

    shadow = true;
    shadow-radius = 20;
    shadow-offset-x = -8;
    shadow-offset-y = -8;
    shadow-opacity = 0.35;
    shadow-color = "#000000";

    corner-radius = 12;
    blur-method = "dual_kawase";
    blur-strength = 7;
    blur-background = true;
    blur-background-frame = true;
    blur-background-fixed = false;

    animations = ({
      triggers = [ "open", "show" ];
      preset = "appear";
      scale = 0.96;
      duration = 0.18;
    }, {
      triggers = [ "close", "hide" ];
      preset = "disappear";
      scale = 0.96;
      duration = 0.14;
    }, {
      triggers = [ "geometry" ];
      preset = "geometry-change";
      duration = 0.20;
    });

    rules = ({
      match = "!focused && !group_focused";
      opacity = 0.84;
    }, {
      match = "focused || group_focused";
      opacity = 0.92;
    }, {
      match = "window_type = 'dock'";
      opacity = 1.0;
      blur-background = true;
      corner-radius = 0;
      shadow = false;
    }, {
      match = "fullscreen";
      opacity = 1.0;
      corner-radius = 0;
      shadow = false;
      blur-background = false;
    }, {
      match = "window_type = 'desktop'";
      opacity = 1.0;
      corner-radius = 0;
      shadow = false;
      blur-background = false;
    }, {
      match = "class_g = 'i3lock'";
      opacity = 1.0;
      corner-radius = 0;
      shadow = false;
      fade = false;
      blur-background = false;
      animations = ({
        triggers = [ "open", "show" ];
        preset = "appear";
        scale = 1.0;
        duration = 0.001;
      }, {
        triggers = [ "close", "hide" ];
        preset = "disappear";
        scale = 1.0;
        duration = 0.001;
      });
    }, {
      match = "window_type = 'tooltip' || window_type = 'popup_menu' || window_type = 'dropdown_menu'";
      opacity = 0.88;
      corner-radius = 8;
      shadow = true;
      blur-background = true;
    });
  '';
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
      extraPackages = [ pkgs.i3blocks ];
    };
  };
  services.displayManager.defaultSession = "none+i3";

  services.autorandr = {
    enable = true;
    defaultTarget = "horizontal";
    matchEdid = true;
  };

  systemd.user.services.picom = {
    description = "Picom composite manager for i3";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${lib.getExe pkgs.picom-pijulius} --config ${picomConfig}";
      Restart = "on-failure";
      RestartSec = 3;
    };
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
    picom-pijulius
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
    mpv
    xwinwrap
    arandr
    xclip
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

    # Runtime-selected GTK/Nautilus appearance and status interactions.
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
