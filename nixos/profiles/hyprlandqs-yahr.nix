{
  pkgs,
  ...
}:

{
  imports = [
    ./common_hyprland.nix
  ];

  environment.systemPackages = with pkgs; [
    # Quickshell bar (yahr QML config from dotfiles)
    quickshell

    # Notification daemon (replaces swaync)
    mako

    # Launcher / menus
    rofi
    wofi

    # Display management (no nwg-dock in QS stack)
    nwg-displays
    nwg-look

    # Power menu
    wlogout

    # Fonts — hypremoji / emoji support in bar
    noto-fonts-color-emoji
    nerd-fonts.jetbrains-mono
    nerd-fonts.symbols-only
  ];
}
