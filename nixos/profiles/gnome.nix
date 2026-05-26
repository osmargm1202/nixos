{ pkgs, ... }:

{
  services.xserver.enable = true;
  security.polkit.enable = true;
  
  services.desktopManager.gnome.enable = true;

  services.displayManager.gdm = {
    enable = true;
    autoSuspend = true;
  };

  environment.systemPackages = with pkgs; [
    gsettings-desktop-schemas
    gnome-tweaks
    gnome-network-displays
    yaru-remix-theme
    gnomeExtensions.user-themes
    gnomeExtensions.blur-my-shell
    gnomeExtensions.appindicator
    gnomeExtensions.caffeine
    gnomeExtensions.removable-drive-menu
    gnomeExtensions.system-monitor
    gnomeExtensions.background-logo
    gnomeExtensions.dash-to-dock
    gnomeExtensions.gnome-40-ui-improvements
    gnomeExtensions.pip-on-top
    gnomeExtensions.tiling-shell
    gnomeExtensions.veil
    gnomeExtensions.burn-my-windows
    gnomeExtensions.clipboard-indicator
    gnomeExtensions.easy-docker-containers
  ];
}
