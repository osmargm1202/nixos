{
  config,
  lib,
  pkgs,
  ...
}:
let
  hostThemeFile = ../hosts/${config.networking.hostName}/sddm-theme.nix;
  hostTheme = if builtins.pathExists hostThemeFile then import hostThemeFile else "black_hole";
in
lib.mkIf (config.orgm.sddm.profile == "astronaut") {
  services.displayManager.sddm = {
    theme = "sddm-astronaut-theme";
    extraPackages = [ pkgs.kdePackages.qtmultimedia ];
  };

  environment.systemPackages = [
    (pkgs.sddm-astronaut.override { embeddedTheme = hostTheme; })
  ];
}
