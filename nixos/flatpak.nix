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
      "com.discordapp.Discord"
      "com.google.EarthPro"
      "com.obsproject.Studio"
      "com.spotify.Client"
      "io.gitlab.theevilskeleton.Upscaler"
      "io.podman_desktop.PodmanDesktop"
      "md.obsidian.Obsidian"
      "org.mozilla.Thunderbird"
      "org.blender.Blender"
      "io.github.intoolswetrust.JSignPdf"
      "org.gimp.GIMP"
      "org.gnome.SimpleScan"
      "org.inkscape.Inkscape"
      "org.libreoffice.LibreOffice"
      "com.github.johnfactotum.Foliate"
    ];
  };
}
