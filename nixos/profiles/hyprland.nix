{
  pkgs,
  userName ? "osmarg",
  ...
}:
{
  imports = [ ./common_hyprland.nix ];

  security.pam.services.hyprlock = { };

  environment.systemPackages = with pkgs; [
    hyprlock
    hypridle
    (rofi.override { plugins = [ rofi-calc ]; })
    libqalculate
    dunst
    bluetui
    nwg-displays
    nwg-dock-hyprland
    pulsemixer
    waybar
  ];

  home-manager.users.${userName}.xdg.desktopEntries.zutty-fast = {
    name = "Zutty Fast";
    genericName = "Terminal Emulator";
    comment = "Fast terminal with the configured Zutty options";
    exec = "zutty-fast";
    icon = "utilities-terminal";
    terminal = false;
    type = "Application";
    categories = [
      "System"
      "TerminalEmulator"
    ];
  };
}
