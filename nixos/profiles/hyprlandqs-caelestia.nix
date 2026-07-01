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
  caelestiaShell = (inputs.caelestia-shell.packages.${system}.with-cli).overrideAttrs (old: {
    buildInputs = old.buildInputs ++ [ pkgs.qt6.qtmultimedia ];
    postPatch = (old.postPatch or "") + ''
      substituteInPlace modules/launcher/services/Emojis.qml \
        --replace-fail 'function recordUsage(char: string)' 'function recordUsage(charStr: string)' \
        --replace-fail 'frequencies[char] = (frequencies[char] || 0) + 1' 'frequencies[charStr] = (frequencies[charStr] || 0) + 1'
    '';
  });
in
{
  imports = [
    ./common_hyprland.nix
  ];

  programs.gpu-screen-recorder.enable = true;

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
    };
  };
}
