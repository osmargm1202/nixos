{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

let
  system = pkgs.stdenv.hostPlatform.system;
  hyprlandPkgs = inputs.hyprland.packages.${system};
  waybarSourceTarget = (pkgs.waybar.override { cavaSupport = false; }).overrideAttrs (old: {
    version = "0.15.0";
    src = inputs.waybar-source-target-src;
  });
  nwgDockHyprlandGit = pkgs.nwg-dock-hyprland.overrideAttrs (old: {
    version = "git-${inputs.nwg-dock-hyprland-src.shortRev or "unknown"}";
    src = inputs.nwg-dock-hyprland-src;
    vendorHash = "sha256-AJGyBCTWtgTpn+e4HLlX/8EgWITw25py4UJJJDLhoOM=";
  });
in
{
  imports = [
    ./common_hyprland.nix
  ];

  security.pam.services.hyprlock = {};

  environment.systemPackages = with pkgs; [
    hyprlock
    # Shell / panel for Hyprland — waybar stack
    waybarSourceTarget
    nwgDockHyprlandGit
    nwg-drawer
    nwg-displays
    nwg-look

    # Hardware tray/TUI (fuera de common_hyprland: caelestia trae los suyos)
    networkmanagerapplet
    bluetui

    # Launchers / notification
    quickshell
    fuzzel
    rofi
    libqalculate
    yad
    wlogout
    swaynotificationcenter
    dunst
  ];
}
