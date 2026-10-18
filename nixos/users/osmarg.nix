{
  lib,
  role,
  userName,
  hostName ? "",
  ...
}:
{
  # Peer-change polling and desktop alerts are independent of the VPN.
  orgm.tailscale.peerNotifications.enable = false;

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
      "syncthing"
      "discord"
      "steam"
      "sunshine"
      "openrgb"
      "containers"
      "orgm"
      "ai"
      "bitwarden-cli"
      "webapps"
      "rmatrix"
      "obsidian"
      "kdeconnect"
      "tailscale"
      "sops"
      "flatpak"
      "deskflow"
    ] ++ lib.optional (hostName != "envy") "nextcloud";

    # Preserve Osmarg's explicit existing startup choices, not host defaults.
    # Background services do not need trays. Sunshine already has its own unit.
    autostart = lib.optional (hostName != "envy") "nextcloud --background" ++ [
      "kdeconnect-indicator"
      "firefox"
      "sh -lc 'command -v discord >/dev/null 2>&1 && exec discord --start-minimized || true'"
      "sh -lc 'command -v steam >/dev/null 2>&1 && exec steam -silent || true'"
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
      "com.spotify.Client"
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
      "perplexity"
      "facebook"
      "instagram"
      "reddit"
      "ubereats"
    ];
  };
}

  # Git identity is an editable user dotfile, copied by orgm-dot.
