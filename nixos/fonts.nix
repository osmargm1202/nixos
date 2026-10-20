{ pkgs, ... }:
{
  # Shared by desktops, terminal/server roles and their boot specialisations.
  # This is the proportional Roboto family, not RobotoMono Nerd Font.
  # pkgs.roboto includes static weights and true italics (including Medium/Bold).
  fonts.fontconfig.enable = true;
  fonts.packages = [ pkgs.roboto ];
}
