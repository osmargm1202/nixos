{
  config,
  lib,
  pkgs,
  ...
}:
lib.mkIf (config.orgm.sddm.profile == "greenshift") {
  services.displayManager.sddm = {
    theme = "GreenShift";
    extraPackages = with pkgs.kdePackages; [
      qt5compat
      qtsvg
    ];
    # GreenShift reads battery state from sysfs through QML XMLHttpRequest.
    settings.General.GreeterEnvironment = lib.concatStringsSep "," (
      [ "QML_XHR_ALLOW_FILE_READ=1" ]
      ++ lib.optional (
        config.services.displayManager.sddm.wayland.enable
        && config.services.displayManager.sddm.wayland.compositor == "kwin"
      ) "QT_WAYLAND_SHELL_INTEGRATION=layer-shell"
    );
  };

  environment.systemPackages = [ (pkgs.callPackage ./sddm-greenshift.nix { }) ];
}
