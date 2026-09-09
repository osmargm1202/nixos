{
  config,
  lib,
  pkgs,
  ...
}:
let
  themePaths = {
    clockwork = "clockwork/orbital";
    wuthering-waves = "wuwa";
  };
  theme = config.orgm.sddm.qylockTheme;
  qylockTheme = pkgs.callPackage ./sddm-qylock.nix {
    inherit theme;
    themePath = themePaths.${theme} or theme;
  };
in
lib.mkIf (config.orgm.sddm.profile == "qylock") {
  services.displayManager.sddm = {
    theme = config.orgm.sddm.qylockTheme;
    # Qylock imports these Qt 6 QML modules. Video themes additionally use the
    # GStreamer plugins below to decode their bundled background media.
    extraPackages = [
      qylockTheme
      pkgs.qt6.qt5compat
      pkgs.qt6.qtmultimedia
      pkgs.qt6.qtsvg
      pkgs.gst_all_1.gstreamer
      pkgs.gst_all_1.gst-plugins-base
      pkgs.gst_all_1.gst-plugins-good
      pkgs.gst_all_1.gst-plugins-bad
      pkgs.gst_all_1.gst-plugins-ugly
    ];
  };

  environment.systemPackages = [ qylockTheme ];
}
