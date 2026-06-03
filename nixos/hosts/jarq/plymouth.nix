{ pkgs, ... }:

let
  themeName = "lenovo-flex";
in
{
  boot.plymouth = {
    theme = themeName;
    themePackages = [
      (pkgs.callPackage ../../plymouth-logo-theme.nix {
        inherit themeName;
        logo = ../../plymouth-logos/lenovo-flex.png;
        background = "0.0, 0.0, 0.0";
        logoScale = 32;
      })
    ];
  };
}
