# Jarq starts from Osmarg's selection without Discord, Steam or the extra
# flatpaks; the lists can diverge from here.
{
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
      "com.anydesk.Anydesk"
      "io.dbeaver.DBeaverCommunity"
      "org.mozilla.Thunderbird"
      "io.github.intoolswetrust.JSignPdf"
      "org.gnome.SimpleScan"
      "org.inkscape.Inkscape"
      "org.gimp.GIMP"
      "org.libreoffice.LibreOffice"
      "org.sqlitebrowser.sqlitebrowser"
      "org.videolan.VLC"
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
