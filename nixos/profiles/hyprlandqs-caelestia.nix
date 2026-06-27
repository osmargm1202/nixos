{
  config,
  pkgs,
  lib,
  inputs,
  userName ? "osmarg",
  ...
}:

let
  system = pkgs.stdenv.hostPlatform.system;
  caelestiaShell = inputs.caelestia-shell.packages.${system}.with-cli;
in
{
  imports = [
    ./common_hyprland.nix
  ];

  environment.systemPackages = with pkgs; [
    # Notification daemon (replaces swaync/waybar)
    mako

    # Launcher / menus
    rofi

    # Display management
    nwg-displays
    nwg-look
    nwg-dock-hyprland

    # Power menu
    wlogout

    # Screen recorder (used by caelestia record)
    gpu-screen-recorder

    # Video wallpapers
    mpvpaper

    # Fonts — hypremoji / emoji support in bar
    noto-fonts-color-emoji
    nerd-fonts.jetbrains-mono
    nerd-fonts.symbols-only
  ];

  home-manager.users.${userName} = {
    imports = [
      inputs.caelestia-shell.homeManagerModules.default
    ];

    programs.caelestia = {
      enable = true;
      package = caelestiaShell;
      settings = {
        bar.workspaces.shown = 10;
      };
    };
  };
}
