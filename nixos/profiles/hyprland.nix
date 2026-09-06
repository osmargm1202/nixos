{
  config,
  lib,
  pkgs,
  inputs,
  userName ? "osmarg",
  ...
}:
let
  hyprlandPackages = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system};
  # Hyprland's locked nixpkgs has Glaze 8.x; pass this flake's compatible 7.x package.
  hyprlandPackage = hyprlandPackages.hyprland.override {
    glaze-hyprland = pkgs.glaze;
  };
  hyprlandPortalPackage = hyprlandPackages.xdg-desktop-portal-hyprland.override {
    hyprland = hyprlandPackage;
  };
  nwgDockHyprland = pkgs.nwg-dock-hyprland.overrideAttrs (_: {
    version = "0.4.11";
    src = pkgs.fetchFromGitHub {
      owner = "nwg-piotr";
      repo = "nwg-dock-hyprland";
      tag = "v0.4.11";
      hash = "sha256-bd/FLQJFn1NERjPvz/wCgjUC88gK+QumIk11vdmjPkY=";
    };
    vendorHash = "sha256-AJGyBCTWtgTpn+e4HLlX/8EgWITw25py4UJJJDLhoOM=";
  });
  mpvpaper19 = pkgs.mpvpaper.overrideAttrs (_: {
    version = "1.9";
    src = pkgs.fetchFromGitHub {
      owner = "GhostNaN";
      repo = "mpvpaper";
      rev = "1.9";
      hash = "sha256-FpwMhzYmbjwvbpJd6xDRka6h2bvgsqdopqP5deQKXSA=";
    };
  });

  waybarWithCaffeineSignal = pkgs.waybar.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace include/modules/idle_inhibitor.hpp \
        --replace-fail \
        'auto update() -> void override;' \
        $'auto update() -> void override;\n  auto refresh(int) -> void override;'
      substituteInPlace src/modules/idle_inhibitor.cpp \
        --replace-fail \
        'void waybar::modules::IdleInhibitor::toggleStatus() {' \
        $'auto waybar::modules::IdleInhibitor::refresh(int sig) -> void {\n#ifdef SIGRTMIN\n  if (config_["signal"].isInt() && sig == SIGRTMIN + config_["signal"].asInt()) {\n    toggleStatus();\n    for (auto const& module : IdleInhibitor::modules) {\n      module->update();\n    }\n  }\n#endif\n}\n\nvoid waybar::modules::IdleInhibitor::toggleStatus() {'
    '';
  });
  scrollOverview =
    (pkgs.callPackage ../packages/hyprland-scroll-overview.nix {
      hyprland = hyprlandPackage;
    }).overrideAttrs
      (_: {
        src = inputs.scrollOverview;
        version = inputs.scrollOverview.shortRev or inputs.scrollOverview.rev;
      });
  hyprGlass = pkgs.callPackage ../packages/hyprglass.nix {
    hyprland = hyprlandPackage;
    src = inputs.hyprglass;
  };
  hyprWindowShade = pkgs.callPackage ../packages/hyprwindowshade.nix {
    hyprland = hyprlandPackage;
    src = inputs.hyprWindowShade;
    niriShaders = inputs.niriShaders;
  };
  hyprKdeconnectFix = pkgs.callPackage ../packages/hypr-kdeconnect-fix.nix { };
  orgmThemes = pkgs.callPackage ../packages/orgm-themes.nix { };
  scrollOverviewLibrary = pkgs.runCommand "scrolloverview.so" { } ''
    ln -s ${scrollOverview}/lib/libscrolloverview.so "$out"
  '';
  hyprGlassLibrary = pkgs.runCommand "hyprglass.so" { } ''
    ln -s ${hyprGlass}/lib/hyprglass.so "$out"
  '';
  hyprWindowShadeLibrary = pkgs.runCommand "HyprWindowShade.so" { } ''
    ln -s ${hyprWindowShade}/lib/HyprWindowShade.so "$out"
  '';
in
{
  imports = [
    ./sddm.nix
    ./printer.nix
    ./vesktop.nix
  ];
  services.xserver.enable = false;
  services.displayManager.defaultSession = "hyprland";

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    package = hyprlandPackage;
    portalPackage = hyprlandPortalPackage;
  };

  environment.etc."scrolloverview.so".source = scrollOverviewLibrary;
  environment.etc."hyprglass.so".source = hyprGlassLibrary;
  # Deliberately only expose the ABI-coupled plugin. After switching generations,
  # unload any prior instance, then manually load /etc/HyprWindowShade.so; never replace it while loaded.
  environment.etc."HyprWindowShade.so".source = hyprWindowShadeLibrary;
  environment.etc."hyprwindowshade-shaders".source =
    "${hyprWindowShade}/share/hyprwindowshade/shaders";

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
    # Upstream Hyprland v0.56.0 compositor and matching portal.
    hyprlandPackage
    xwayland
    hyprGlass
    hyprpaper
    mpvpaper19
    orgmThemes
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
    libqalculate
    dunst
    bluetui
    blueman
    networkmanagerapplet
    nextcloud-client
    nwg-displays
    nwgDockHyprland
    pulsemixer
    waybarWithCaffeineSignal
  ];

  assertions = [
    {
      assertion = lib.hasPrefix "0.56.2" hyprlandPackage.version;
      message = "The selected upstream Hyprland platform requires the exact 0.56.2 release family; the flake input is the exact release pin.";
    }
  ];

  security.pam.services.hyprlock = { };

}
