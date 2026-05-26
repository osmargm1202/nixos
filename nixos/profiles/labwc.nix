{ pkgs, inputs, ... }:

let
  sddmAstronautTheme = pkgs.callPackage ../packages/sddm-astronaut-theme.nix {
    src = inputs.sddm-astronaut-theme;
  };
in
{
  imports = [
    inputs.dms.nixosModules.dank-material-shell
  ];

  services.xserver.enable = true;
  services.displayManager = {
    defaultSession = "labwc";
    sddm = {
      enable = true;
      wayland.enable = true;
      autoNumlock = true;
      theme = "sddm-astronaut-theme";
      extraPackages = with pkgs.qt6; [
        qtmultimedia
        qtsvg
        qtvirtualkeyboard
      ];
      settings.General = {
        InputMethod = "qtvirtualkeyboard";
        Numlock = "on";
      };
    };
  };

  programs.labwc.enable = true;
  programs.xwayland.enable = true;

  programs.dank-material-shell = {
    enable = true;
    # Labwc arranca DMS desde autostart con `dms run -d`.
    # El servicio systemd fallaba buscando `qs` en PATH.
    systemd.enable = false;
    enableClipboardPaste = true;
    enableDynamicTheming = true;
    enableSystemMonitoring = false;
  };

  programs.nautilus-open-any-terminal = {
    enable = true;
    terminal = "kitty";
  };

  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-wlr
      xdg-desktop-portal-gtk
    ];
    config = {
      common.default = [
        "wlr"
        "gtk"
      ];
      wlroots.default = [
        "wlr"
        "gtk"
      ];
      labwc = {
        default = [
          "wlr"
          "gtk"
        ];
        "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
        "org.freedesktop.impl.portal.OpenURI" = [ "gtk" ];
      };
    };
  };

  xdg.terminal-exec = {
    enable = true;
    settings = {
      labwc = [ "kitty.desktop" ];
      default = [ "kitty.desktop" ];
    };
  };

  xdg.mime = {
    enable = true;
    defaultApplications = {
      "inode/directory" = [ "org.gnome.Nautilus.desktop" ];
    };
  };

  security.polkit.enable = true;
  security.pam.services.sddm.enableGnomeKeyring = true;
  security.pam.services.login.enableGnomeKeyring = true;

  services.dbus.enable = true;
  services.gvfs.enable = true;
  services.gnome.gnome-keyring.enable = true;
  programs.dconf.enable = true;

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
    XDG_SESSION_TYPE = "wayland";
    XDG_SESSION_DESKTOP = "labwc";
    XDG_CURRENT_DESKTOP = "labwc:wlroots";
    QT_QPA_PLATFORM = "wayland";
    QT_QPA_PLATFORMTHEME = "gtk3";
    QT_QPA_PLATFORMTHEME_QT6 = "gtk3";
    GTK_THEME = "Adwaita:dark";
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
    TERMINAL = "kitty";
  };

  environment.systemPackages = with pkgs; [
    labwc
    xwayland

    sddmAstronautTheme
    kitty
    fuzzel
    quickshell
    wlogout
    swaynotificationcenter
    swayidle
    gsettings-desktop-schemas
    wlopm

    mpv
    ffmpeg

    xdg-utils
    xdg-desktop-portal
    xdg-desktop-portal-wlr
    xdg-desktop-portal-gtk

    wl-clipboard
    cliphist
    grim
    slurp
    swappy
    wlr-randr
    wlrctl
    wtype
    brightnessctl
    pamixer
    playerctl

    pavucontrol
    networkmanagerapplet
    blueman
    wdisplays

    nautilus
    gnome-software
    gnome-text-editor
    apostrophe
    loupe
    gnome-calculator
    gnome-maps
    gnome-system-monitor
    file-roller
    baobab
    totem
    gnome-photos
    evince
    gnome-disk-utility
    gnome-logs
    seahorse
    gnome-font-viewer
    gnome-characters

    adwaita-icon-theme
    papirus-icon-theme
    hicolor-icon-theme
    gnome-themes-extra
    gnome-tweaks
    yaru-remix-theme

    shared-mime-info
    dconf
    glib
    gnome-keyring
    polkit_gnome
  ];
}
