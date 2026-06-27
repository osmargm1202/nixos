{
  pkgs,
  inputs,
  ...
}:

let
  system = pkgs.stdenv.hostPlatform.system;
  hyprlandPkgs = inputs.hyprland.packages.${system};
in
{
  imports = [
    ./common_hyprland.nix
  ];

  environment.systemPackages = with pkgs; [
    # Quickshell bar (yahr QML config from dotfiles)
    quickshell

    # Notification daemon (replaces swaync)
    mako

    # Launcher
    wofi
    fuzzel

    # Display management (no nwg-dock in QS stack)
    nwg-displays
    nwg-look

    # Power menu
    wlogout

    # Fonts — hypremoji for emoji support in bar
    noto-fonts-emoji
    (nerdfonts.override { fonts = [ "JetBrainsMono" "NerdFontsSymbolsOnly" ]; })
  ];
}
