{ pkgs, ... }:

let
  themeName = "ero-orgm";
in
{
  boot.plymouth = {
    theme = themeName;
    themePackages = [
      (pkgs.callPackage ../../plymouth-logo-theme.nix {
        inherit themeName;
        logo = ../../plymouth-logos/gateway.png;
        background = "0.0, 0.0, 0.0";
        logoScale = 42;
      })
    ];
  };
}
