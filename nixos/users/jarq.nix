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
      "nextcloud"
      "tailscale"
      "webapps"
      "flatpak"
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
      "outlook"
      "teams"
    ];
  };

  orgm.tailscale.peerNotifications.enable = true;
}
