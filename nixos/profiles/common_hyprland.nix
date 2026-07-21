{
  config,
  pkgs,
  lib,
  inputs,
  userName ? "osmarg",
  ...
}:

let
  system = pkgs.stdenv.hostPlatform.system;
  hyprlandPkgs = inputs.hyprland.packages.${system};
  hyprpaperPkg = inputs.hyprpaper.packages.${system}.hyprpaper;
  dotfilesOrgmSource = ../../dotfiles;
  orgmThemes = pkgs.callPackage ../packages/orgm-themes.nix { inherit dotfilesOrgmSource; };
  zenBrowser = pkgs.callPackage ../packages/zen-browser.nix { zenBrowserFlakeSrc = inputs.zen-browser-flake; };
  psdZen = pkgs.callPackage ../packages/psd-zen.nix { };
  vesktopNoInputVolumeAdjustment = pkgs.symlinkJoin {
    name = "vesktop-no-input-volume-adjustment-${pkgs.vesktop.version}";
    paths = [ pkgs.vesktop ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/vesktop \
        --add-flags "--disable-features=WebRtcAllowInputVolumeAdjustment"
    '';
  };
  # brave-origin removido del closure (~404 MB); nix file conservado.
  sddmKwinOutputConfig = ../hosts/${config.networking.hostName}/sddm-kwinoutputconfig.json;
  hasSddmKwinOutputConfig = builtins.pathExists sddmKwinOutputConfig;
  scrollOverviewSo = pkgs.runCommand "scrolloverview.so" { } ''
    cp ${inputs.hyprland-scroll-overview.packages.${system}.default}/lib/libscrolloverview.so $out
  '';
in
{
  imports = [
    ./sddm.nix
    ./printer.nix
  ];

  services.xserver.enable = false;
  services.displayManager.defaultSession = "hyprland";

  environment.etc = lib.mkMerge [
    (lib.mkIf hasSddmKwinOutputConfig {
      "sddm/kwinoutputconfig-${config.networking.hostName}.json".source = sddmKwinOutputConfig;
    })
    {
      # Tab-group Lua plugin source, exposed at a stable path so hyprland.lua
      # can `package.path`+`require` it without a manual git clone. Inert
      # unless a profile's hyprland.lua requires it (see lua/hyprdeck.lua).
      "hyprdeck".source = inputs.hyprdeck;

      # Compiled Hyprland plugin (niri-style scroll overview). Built via
      # inputs.hyprland-scroll-overview.inputs.hyprland.follows = "hyprland"
      # in flake.nix so it's linked against our exact Hyprland rev -- the
      # plugin ABI hash check fails at load time otherwise. Exposed at a
      # stable path so each profile's autostart.lua can `hyprctl plugin load`
      # it without depending on the store path directly.
      "scrolloverview.so".source = scrollOverviewSo;
    }
  ];
  systemd.tmpfiles.rules = lib.optionals hasSddmKwinOutputConfig [
    "d /var/lib/sddm/.config 0755 sddm sddm -"
    "C /var/lib/sddm/.config/kwinoutputconfig.json 0644 sddm sddm - /etc/sddm/kwinoutputconfig-${config.networking.hostName}.json"
  ];

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    package = hyprlandPkgs.hyprland;
    portalPackage = hyprlandPkgs.xdg-desktop-portal-hyprland;
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
  # UPower DBus daemon — caelestia/quickshell BatteryMonitor reads battery via
  # Quickshell.Services.UPower; without it the shell reports "no battery".
  services.upower.enable = true;

  services.dbus.enable = true;
  services.udisks2.enable = true;
  services.gvfs.enable = true;
  services.gvfs.package = pkgs.gnome.gvfs.override {
    googleSupport = true;
  };
  nixpkgs.config.permittedInsecurePackages = [ "libsoup-2.74.3" ];
  services.gnome.gnome-keyring.enable = true;
  programs.dconf.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      hyprlandPkgs.xdg-desktop-portal-hyprland
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
        text/html=zen-browser.desktop
        application/xhtml+xml=zen-browser.desktop
        x-scheme-handler/http=zen-browser.desktop
        x-scheme-handler/https=zen-browser.desktop
        x-scheme-handler/chrome=zen-browser.desktop
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

      xdg.configFile."psd/psd.conf".text = ''
        BROWSERS=(zen chromium)
      '';

      systemd.user.services.psd = {
        Unit = {
          Description = "Profile-sync-daemon";
          Wants = [ "psd-resync.service" ];
          RequiresMountsFor = [ "/home/" ];
        };
        Service = {
          Type = "oneshot";
          RemainAfterExit = true;
          # Explicit PATH -- without it, psd's rsync/grep/awk/uname calls
          # race the session's PATH import at early boot and fail silently
          # (systemd retries until it wins the race), which can leave the
          # "unsync" step never running cleanly before shutdown.
          Environment = "PATH=${
            lib.makeBinPath [
              pkgs.rsync
              pkgs.gnugrep
              pkgs.gawk
              pkgs.coreutils
              pkgs.util-linux
              pkgs.procps
              pkgs.psmisc
            ]
          }";
          ExecStart = "${psdZen}/bin/profile-sync-daemon startup";
          ExecStop = "${psdZen}/bin/profile-sync-daemon unsync";
          TimeoutStopSec = 60;
        };
        Install.WantedBy = [ "default.target" ];
      };

      systemd.user.services.psd-resync = {
        Unit = {
          Description = "Timed resync";
          After = [ "psd.service" ];
          BindsTo = [ "psd.service" ];
        };
        Service = {
          Type = "oneshot";
          Environment = "PATH=${
            lib.makeBinPath [
              pkgs.rsync
              pkgs.gnugrep
              pkgs.gawk
              pkgs.coreutils
              pkgs.util-linux
              pkgs.procps
              pkgs.psmisc
            ]
          }";
          ExecStart = "${psdZen}/bin/profile-sync-daemon resync";
        };
      };

      systemd.user.timers.psd-resync = {
        Unit.Description = "Timer for profile-sync-daemon - 1Hour";
        Unit.BindsTo = [ "psd.service" ];
        Timer.OnUnitActiveSec = "1h";
        Install.WantedBy = [ "timers.target" ];
      };
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
      "text/html" = [ "zen-browser.desktop" ];
      "application/xhtml+xml" = [ "zen-browser.desktop" ];
      "x-scheme-handler/http" = [ "zen-browser.desktop" ];
      "x-scheme-handler/https" = [ "zen-browser.desktop" ];
      "x-scheme-handler/chrome" = [ "zen-browser.desktop" ];
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
    # Hyprland-native stack
    hyprlandPkgs.hyprland
    xwayland
    hyprpaperPkg
    mpvpaper
    matugen
    orgmThemes
    ffmpeg
    steamcmd
    python3Minimal
    hypridle
    hyprpicker
    hyprsunset
    hyprpolkitagent

    # Browser
    zenBrowser
    psdZen

    # Portal / XDG
    xdg-utils
    desktop-file-utils
    xdg-desktop-portal
    hyprlandPkgs.xdg-desktop-portal-hyprland
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

    # Communication
    vesktopNoInputVolumeAdjustment

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
}
