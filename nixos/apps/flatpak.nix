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

    # Retire only the replaced client, including copies not recorded in the
    # nix-flatpak state. Other manually installed applications remain managed
    # by their existing owner.
    systemd.services.flatpak-managed-install.postStart = ''
      if ${pkgs.flatpak}/bin/flatpak info --system com.spotify.Client >/dev/null 2>&1 \
        && ${pkgs.flatpak}/bin/flatpak info --system rocks.fastpotify.Fastpotify >/dev/null 2>&1; then
        ${pkgs.flatpak}/bin/flatpak uninstall --system --noninteractive --assumeyes rocks.fastpotify.Fastpotify
      fi
    '';

    home-manager.users.${userName} = { lib, ... }: {
      config = lib.mkMerge [ {
      home.activation.removeFastpotify = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if ${pkgs.flatpak}/bin/flatpak info --user rocks.fastpotify.Fastpotify >/dev/null 2>&1; then
          $DRY_RUN_CMD ${pkgs.flatpak}/bin/flatpak uninstall --user --noninteractive --assumeyes rocks.fastpotify.Fastpotify
        fi
      '';
    } (lib.mkIf discordEnabled {
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
      }) ];
    };
  };
}
