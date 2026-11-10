# X13 only: keep GNOME's native services and the user's chosen applications.
{ lib, pkgs, userName, ... }:
let
  redundant = [
    "udiskie" "blueman" "totem" "showtime" "papers"
    "simple-scan" "gnome-connections" "gnome-maps"
  ];
  keep = package: !(builtins.elem (lib.getName package) redundant);
in {
  # Filter the final package lists, including shared and GNOME core additions.
  # This host-local option transformation avoids copying or forcing shared lists.
  options.environment.systemPackages = lib.mkOption {
    apply = packages: builtins.filter keep packages;
  };
  config = {
    services.blueman.enable = lib.mkForce false;
    systemd.user.services.udiskie = {
      enable = lib.mkForce false;
      wantedBy = lib.mkForce [];
    };
    # Keep the imported UDisks2, GVfs, MTP/AFC and BlueZ infrastructure.
    environment.systemPackages = [ pkgs.snapshot pkgs.gnome-sound-recorder ];
    home-manager.users.${userName} = {
      options.home.packages = lib.mkOption {
        apply = packages: builtins.filter keep packages;
      };
      config.dconf.settings."org/gnome/desktop/media-handling" = {
        automount = true;
        automount-open = true;
      };
    };
    # Keep Evince as the single native PDF viewer (PDFCraft stays the default).
    # Simple Scan's selected Flatpak remains, as do VLC and Remmina.
    # Browser/webapp packages and Discord packaging are intentionally untouched.
  };
}
