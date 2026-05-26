{ pkgs, ... }:

{
  services.xserver.enable = true;
  services.displayManager = {
    defaultSession = "labwc";
    sddm = {
      enable = true;
      wayland.enable = true;
      autoNumlock = true;
    };
  };

  programs.labwc.enable = true;
  programs.xwayland.enable = true;

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

  security.polkit.enable = true;
  services.dbus.enable = true;
  services.gvfs.enable = true;

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
    XDG_SESSION_TYPE = "wayland";
    XDG_SESSION_DESKTOP = "labwc";
    XDG_CURRENT_DESKTOP = "labwc:wlroots";
    QT_QPA_PLATFORM = "wayland";
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
    TERMINAL = "kitty";
  };

  environment.systemPackages = with pkgs; [
    labwc
    xwayland

    fuzzel
    kitty
    nautilus
    mpvpaper

    grim
    slurp
    wl-clipboard

    xdg-utils
    xdg-desktop-portal
    xdg-desktop-portal-wlr
    xdg-desktop-portal-gtk

    podman
    podman-compose
    distrobox

    shared-mime-info
    polkit_gnome
  ];
}
