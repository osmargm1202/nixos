{
  lib,
  pkgs,
  ...
}:
let
  windowsManagerLinuxOrgm = pkgs.callPackage ./packages/windows-manager-linux-orgm.nix { };
  signedWindowsManagerLinuxOrgm = ./packages/windows-manager-linux-orgm/windows-manager-linux-orgm-signed.xpi;
  grungeImpactTheme = ./packages/firefox-themes/grunge-impact-1.0.xpi;
  grungeImpactThemeId = "{59129a6b-d6a6-452b-a5a6-df49f45ad943}";
  hasSignedWindowsManagerLinuxOrgm = builtins.pathExists signedWindowsManagerLinuxOrgm;
in
{
  warnings = lib.optional (!hasSignedWindowsManagerLinuxOrgm) ''
    Browser tab focusing is inactive until the signed AMO XPI is added at nixos/packages/windows-manager-linux-orgm/windows-manager-linux-orgm-signed.xpi.
  '';

  environment.systemPackages = [ windowsManagerLinuxOrgm ];

  programs.firefox = {
    enable = true;
    nativeMessagingHosts.packages = [ windowsManagerLinuxOrgm ];
    policies = {
      ExtensionSettings =
        {
          "${grungeImpactThemeId}" = {
            installation_mode = "force_installed";
            install_url = "file://${grungeImpactTheme}";
          };
        }
        // lib.optionalAttrs hasSignedWindowsManagerLinuxOrgm {
          "windows_manager_linux_orgm@or-gm.com" = {
            installation_mode = "force_installed";
            install_url = "file://${signedWindowsManagerLinuxOrgm}";
          };
        };
    };
  };

  xdg.mime = {
    enable = true;
    defaultApplications = {
      "text/html" = [ "firefox.desktop" ];
      "application/xhtml+xml" = [ "firefox.desktop" ];
      "x-scheme-handler/http" = [ "firefox.desktop" ];
      "x-scheme-handler/https" = [ "firefox.desktop" ];
    };
  };
}
