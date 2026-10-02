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
  fastpotifyId = "rocks.fastpotify.Fastpotify";
  fastpotify = rec {
    appId = fastpotifyId;
    bundle = "${pkgs.fetchurl {
      url = "https://github.com/crmne/fastpotify/releases/download/v0.6.0/fastpotify-v0.6.0-x86_64.flatpak";
      hash = "sha256-BC14bYQqQm+dsUFLE600ApnPFqORPKVVCn1CXI7HSt4=";
    }}";
    sha256 = "sha256-BC14bYQqQm+dsUFLE600ApnPFqORPKVVCn1CXI7HSt4=";
  };
  packages = map (
    package: if package == fastpotifyId then fastpotify else package
  ) config.orgm.user.flatpakPackages;
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
