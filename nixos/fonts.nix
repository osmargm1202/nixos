{ pkgs, ... }:
{
  # Shared by desktops, terminal/server roles and their boot specialisations.
  # This is the proportional Roboto family, not RobotoMono Nerd Font.
  # pkgs.roboto supplies BOTH Roboto and the real Roboto Condensed family.
  # Condensed includes Light/Regular/Medium/Bold and the corresponding italics.
  # Keep a single package: adding another Condensed version creates duplicate faces.
  fonts.fontconfig.enable = true;
  fonts.packages = [ pkgs.roboto ];
}
