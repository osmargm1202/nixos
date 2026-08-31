{
  lib,
  pkgs,
  userName,
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
      Homepage.StartPage = "previous-session";
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

  home-manager.users.${userName} = { lib, ... }: {
    home.file.".zen/native-messaging-hosts/windows_manager_linux_orgm.json".source =
      "${windowsManagerLinuxOrgm}/lib/mozilla/native-messaging-hosts/windows_manager_linux_orgm.json";

    home.activation.installZenTabBridge = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      profiles_ini="$HOME/.zen/profiles.ini"
      if [[ -r "$profiles_ini" ]]; then
        profile_path=""
        while IFS= read -r line; do
          case "$line" in
            "[Profile"*"]") profile_path="" ;;
            "Path="*) profile_path="''${line#Path=}" ;;
            "Default=1") [[ -n "$profile_path" ]] && break ;;
          esac
        done < "$profiles_ini"

        case "$profile_path" in
          "" | /* | .. | ../* | */../*) ;;
          *)
            target_dir="$HOME/.zen/$profile_path/extensions"
            $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p "$target_dir"
            $DRY_RUN_CMD ${pkgs.coreutils}/bin/ln -sfn ${signedWindowsManagerLinuxOrgm} "$target_dir/windows_manager_linux_orgm@or-gm.com.xpi"
            ;;
        esac
      fi
    '';
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
