{ pkgs, userName ? "osmarg", ... }:

let
  discord = pkgs.callPackage ./discord-webrtc.nix { };
in
{
  environment.systemPackages = [ discord ];

  services.fwupd.enable = true;

  services.flatpak = {
    enable = true;

    remotes = [
      {
        name = "flathub";
        location = "https://flathub.org/repo/flathub.flatpakrepo";
      }
    ];

    overrides = { };

    packages = [
      "be.alexandervanhee.gradia"
      "com.anydesk.Anydesk"
      "com.discordapp.Discord"
      "com.google.EarthPro"
      "com.moonlight_stream.Moonlight"
      "com.obsproject.Studio"
      "io.dbeaver.DBeaverCommunity"
      "io.github.hmlendea.geforcenow-electron"
      "io.gitlab.theevilskeleton.Upscaler"
      "io.podman_desktop.PodmanDesktop"
      "md.obsidian.Obsidian"
      "com.rustdesk.RustDesk"
      rec {
        appId = "rocks.fastpotify.Fastpotify";
        bundle = "${pkgs.fetchurl {
          url = "https://github.com/crmne/fastpotify/releases/download/v0.6.0/fastpotify-v0.6.0-x86_64.flatpak";
          hash = "sha256-BC14bYQqQm+dsUFLE600ApnPFqORPKVVCn1CXI7HSt4=";
        }}";
        sha256 = "sha256-BC14bYQqQm+dsUFLE600ApnPFqORPKVVCn1CXI7HSt4=";
      }
      "org.mozilla.Thunderbird"
      "org.blender.Blender"
      "io.github.intoolswetrust.JSignPdf"
      "org.gimp.GIMP"
      "org.gnome.SimpleScan"
      "org.inkscape.Inkscape"
      "org.libreoffice.LibreOffice"
      "org.sqlitebrowser.sqlitebrowser"
      "org.videolan.VLC"
      "com.github.johnfactotum.Foliate"
    ];
  };

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
