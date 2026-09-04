{ ... }:

{
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
}
