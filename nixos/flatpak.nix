{ ... }:

{
  services.flatpak = {
    enable = true;

    remotes = [
      {
        name = "flathub";
        location = "https://flathub.org/repo/flathub.flatpakrepo";
      }
    ];

    packages = [
      "app.zen_browser.zen"
      "org.chromium.Chromium"
      "com.pokemmo.PokeMMO"
      "com.valvesoftware.Steam"
      "be.alexandervanhee.gradia"
      "com.obsproject.Studio"
      "io.gitlab.theevilskeleton.Upscaler"
      "com.spotify.Client"
      "org.pulseaudio.pavucontrol"
      "md.obsidian.Obsidian"
      "org.gnome.Papers"
      "org.gnome.gitlab.somas.Apostrophe"
      "org.libreoffice.LibreOffice"
      "com.discordapp.Discord"
      "org.mozilla.Thunderbird"
      "fr.arnaudmichel.launcherstudio"
      "io.podman_desktop.PodmanDesktop"
      "org.blender.Blender"
      "org.gimp.GIMP"
      "org.inkscape.Inkscape"
      "com.google.EarthPro"
      "best.ellie.StartupConfiguration"
      "com.vixalien.sticky"
      "io.github.flattool.Warehouse"
      "io.github.realmazharhussain.GdmSettings"
      "org.gnome.FileRoller"
      "org.gnome.SimpleScan"
    ];
  };
}
