{
  pkgs,
  userName ? "osmarg",
  ...
}:

let
  discord = pkgs.callPackage ../packages/discord-webrtc.nix { };
  vesktop = pkgs.callPackage ../packages/vesktop-webrtc.nix { };
in
{
  environment.systemPackages = [
    discord
    vesktop
  ];

  home-manager.users.${userName}.xdg.desktopEntries."com.discordapp.Discord" = {
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
}
