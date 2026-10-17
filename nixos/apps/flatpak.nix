{
  config,
  lib,
  pkgs,
  userName ? "osmarg",
  ...
}:
let
  enabled = builtins.elem "flatpak" config.orgm.user.programs;
  discordEnabled = builtins.elem "discord" config.orgm.user.programs;
  packages = config.orgm.user.flatpakPackages;
  discord = pkgs.callPackage ./discord-webrtc.nix { };
in
{
  config = lib.mkIf enabled {
    environment.systemPackages = lib.optional discordEnabled discord;

    services.fwupd.enable = true;
    services.flatpak = {
      enable = packages != [ ];
      remotes = [
        {
          name = "flathub";
          location = "https://flathub.org/repo/flathub.flatpakrepo";
        }
      ];
      overrides = { };
      inherit packages;
    };

    home-manager.users.${userName} = lib.mkIf discordEnabled {
      xdg.desktopEntries."com.discordapp.Discord" = {
        name = "Discord";
        genericName = "Internet Messenger";
        comment = "All-in-one voice and text chat";
        exec = "${discord}/bin/discord %U";
        icon = "com.discordapp.Discord";
        terminal = false;
        type = "Application";
        categories = [
          "Network"
          "InstantMessaging"
        ];
        mimeType = [ "x-scheme-handler/discord" ];
        settings = {
          StartupWMClass = "discord";
          X-Flatpak = "com.discordapp.Discord";
        };
      };
    };
  };
}
