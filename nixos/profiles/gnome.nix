{ pkgs, ... }:

{
  imports = [ ./sddm.nix ./printer.nix ];

  services.xserver.enable = true;
  security.polkit.enable = true;
  services.dbus.enable = true;
  services.gvfs.enable = true;
  nixpkgs.config.permittedInsecurePackages = [ "libsoup-2.74.3" ];
  services.gnome.gnome-keyring.enable = true;
  programs.dconf.enable = true;
  security.pam.services.login.enableGnomeKeyring = true;
  services.power-profiles-daemon.enable = true;

  services.desktopManager.gnome.enable = true;
  services.displayManager.defaultSession = "gnome";

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
    GDK_BACKEND = "wayland,x11";
  };

  xdg.mime = {
    enable = true;
    defaultApplications = {
      "inode/directory" = [ "org.gnome.Nautilus.desktop" ];
      "text/plain" = [ "org.gnome.TextEditor.desktop" ];
      "application/pdf" = [ "org.gnome.Evince.desktop" ];
      "image/png" = [ "org.gnome.Loupe.desktop" ];
      "image/jpeg" = [ "org.gnome.Loupe.desktop" ];
      "image/webp" = [ "org.gnome.Loupe.desktop" ];
      "application/zip" = [ "org.gnome.FileRoller.desktop" ];
    };
  };

  environment.systemPackages = with pkgs; [
    # GNOME core apps / integration
    gsettings-desktop-schemas
    nautilus
    gnome-online-accounts-gtk
    gnome-console
    gnome-text-editor
    loupe
    evince
    file-roller
    baobab
    gnome-calculator
    gnome-disk-utility
    gnome-logs
    gnome-system-monitor
    seahorse
    gnome-font-viewer
    gnome-characters
    sushi
    gnome-software
    rofi

    # Tweaks / themes
    gnome-tweaks
    gnome-network-displays
    yaru-remix-theme

    # Stable-ish GNOME extensions
    gnomeExtensions.user-themes
    gnomeExtensions.appindicator
    gnomeExtensions.caffeine
    gnomeExtensions.removable-drive-menu
    gnomeExtensions.system-monitor
    gnomeExtensions.dash-to-dock
    gnomeExtensions.pip-on-top
    gnomeExtensions.tiling-shell
    gnomeExtensions.clipboard-indicator
    gnomeExtensions.easy-docker-containers

    # Visual / experimental: first disable if Shell stutters
    gnomeExtensions.blur-my-shell
    gnomeExtensions.background-logo
    gnomeExtensions.gnome-40-ui-improvements
    gnomeExtensions.veil
    gnomeExtensions.burn-my-windows
  ];
}
