{
  lib,
  pkgs,
  ...
}:
{
  # UDisks covers USB mass-storage devices. GVfs supplies MTP (Android) and
  # AFC (iPhone) backends; iOS therefore appears in the file manager, not as
  # a /dev/sdX block device.
  services.udisks2.enable = true;
  services.usbmuxd.enable = true;
  services.gvfs = {
    enable = true;
    package = pkgs.gnome.gvfs.override {
      gnomeSupport = true;
    };
  };

  environment.systemPackages = [
    pkgs.udiskie
    pkgs.usbutils
    pkgs.gphoto2
    pkgs.ifuse
    pkgs.libimobiledevice
  ];

  systemd.user.services.udiskie = {
    description = "Automount removable storage in graphical sessions";
    wantedBy = [
      "graphical-session.target"
      "nixos-fake-graphical-session.target"
    ];
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    path = [ pkgs.xdg-utils ];
    serviceConfig = {
      ExecStart = "${lib.getExe' pkgs.udiskie "udiskie"} --automount --notify --tray";
      Restart = "on-failure";
      RestartSec = 3;
    };
  };
}
