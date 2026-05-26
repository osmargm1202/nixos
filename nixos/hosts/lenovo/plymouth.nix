{ pkgs, ... }:

let
  themeName = "lenovo-orgm";
in
{
  # Lenovo uses a HiDPI framebuffer after Plymouth; set the virtual console
  # font explicitly so TTYs stay readable without running `setfont -d`.
  console = {
    earlySetup = true;
    packages = [ pkgs.terminus_font ];
    font = "ter-v32n";
  };

  boot.plymouth = {
    theme = themeName;
    themePackages = [
      (pkgs.callPackage ../../plymouth-logo-theme.nix {
        inherit themeName;
        logo = ../../plymouth-logos/lenovo.png;
        background = "0.0, 0.0, 0.0";
        logoScale = 30;
      })
    ];
  };
}
