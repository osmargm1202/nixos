{
  lib,
  role,
  userName,
  ...
}:
{
  orgm.user = {
    programs = [
      "shell"
      "git"
      "tmux"
      "kitty"
      "zutty"
      "neovim"
      "development"
      "personal-development"
      "nextcloud"
      "syncthing"
      "discord"
      "steam"
      "sunshine"
      "openrgb"
      "containers"
      "orgm"
      "ai"
      "webapps"
      "rmatrix"
      "obsidian"
      "kdeconnect"
      "tailscale"
      "sops"
      "flatpak"
      "deskflow"
    ];

    flatpakPackages = [
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
      "rocks.fastpotify.Fastpotify"
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

    webapps = [
      "youtube"
      "youtube-kids"
      "netflix"
      "hbo-max"
      "crunchyroll"
      "poki"
      "gmail"
      "google-maps"
      "outlook"
      "teams"
      "whatsapp"
      "cloud-orgm"
      "webui"
      "banco-popular"
      "github"
      "google-cloud"
      "neon"
      "rollbar"
      "google-ai-studio"
      "excalidraw"
      "fast"
      "claude"
      "chatgpt"
      "facebook"
      "instagram"
      "reddit"
      "ubereats"
    ];
  };
}

  # The identity is user-local. Servers that do not load Home Manager keep no
  # implicit Git identity.
// lib.optionalAttrs (role != "server") {
    home-manager.users.${userName} = {
      programs.git = {
        enable = true;
        settings.user = {
          name = "osmar";
          email = "osmargm1202@gmail.com";
        };
      };
    };
}
