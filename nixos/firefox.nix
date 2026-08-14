{
  lib,
  pkgs,
  ...
}:
let
  windowsManagerLinuxOrgm = pkgs.callPackage ./packages/windows-manager-linux-orgm.nix { };
  signedWindowsManagerLinuxOrgm = ./packages/windows-manager-linux-orgm/windows-manager-linux-orgm-signed.xpi;
  amoXpi = id: "https://addons.mozilla.org/firefox/downloads/latest/${id}/latest.xpi";
  defaultThemeId = "{22b0eca1-8c02-4c0d-a5d7-6604ddd9836e}";
  adBlockId = "jid1-NIfFY2CA8fy1tg@jetpack";
  bitwardenId = "{446900e4-71c2-419f-a6a7-df9c091e268b}";
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
          "${defaultThemeId}" = {
            installation_mode = "force_installed";
            install_url = amoXpi defaultThemeId;
          };
          "${adBlockId}" = {
            installation_mode = "force_installed";
            install_url = amoXpi adBlockId;
          };
          "${bitwardenId}" = {
            installation_mode = "force_installed";
            install_url = amoXpi bitwardenId;
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
      "text/html" = [ "chromium-browser.desktop" ];
      "application/xhtml+xml" = [ "chromium-browser.desktop" ];
      "x-scheme-handler/http" = [ "firefox.desktop" ];
      "x-scheme-handler/https" = [ "firefox.desktop" ];
    };
  };
}
