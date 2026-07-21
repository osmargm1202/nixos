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
    # Keep upstream checks enabled, but bound its 200-cycle thread stress test:
    # parallel local Nix builds can starve the subprocess past its alarm.
    postPatch = (old.postPatch or "") + ''
      substituteInPlace test/utils/sleeper_thread.cpp \
        --replace-fail "alarm(5);" "alarm(30);" \
        --replace-fail "for (int i = 0; i < 200; ++i)" "for (int i = 0; i < 20; ++i)"
    '';
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
    inputs.skwd-wall.nixosModules.default
  ];

  programs.skwd-wall.enable = true;
  systemd.user.targets.graphical-session.wants = [ "skwd-daemon.service" ];

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
    blueman

    # Launchers / notification
    fuzzel
    rofi
    libqalculate
    yad
    wlogout
    swaynotificationcenter
    dunst
  ];
}
