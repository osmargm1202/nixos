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
      "be.alexandervanhee.gradia"
      "com.discordapp.Discord"
      "com.google.EarthPro"
      "com.obsproject.Studio"
      "com.pokemmo.PokeMMO"
      "com.spotify.Client"
      "fr.arnaudmichel.launcherstudio"
      "io.github.realmazharhussain.GdmSettings"
      "io.gitlab.theevilskeleton.Upscaler"
      "io.podman_desktop.PodmanDesktop"
      "md.obsidian.Obsidian"
      "net.thunderbird.Thunderbird"
      "org.blender.Blender"
      "org.gimp.GIMP"
      "org.gnome.SimpleScan"
      "org.inkscape.Inkscape"
      "org.libreoffice.LibreOffice"
      "org.yuzu_emu.yuzu"
    ];
  };
}
