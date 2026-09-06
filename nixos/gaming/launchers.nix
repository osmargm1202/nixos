{
  pkgs,
  userName ? "osmarg",
  ...
}:

{
  environment.systemPackages = with pkgs; [
    # Optional launchers/frontends; import this module only on hosts that need them.
    # lutris
    # heroic
    # bottles
    # retroarch
  ];

  home-manager.users.${userName}.xdg.desktopEntries = {
    dota = {
      name = "Dota 2";
      exec = "steam steam://rungameid/570";
      icon = "${../../dotfiles/assets/gaming/dota2.png}";
      terminal = false;
      categories = [ "Game" ];
      settings.StartupWMClass = "Dota 2";
    };
    silksong = {
      name = "Hollow Knight Silksong";
      exec = "steam steam://rungameid/1030300";
      icon = "${../../dotfiles/assets/gaming/silksong.png}";
      terminal = false;
      categories = [ "Game" ];
      settings.StartupWMClass = "Hollow Knight Silksong";
    };
  };
}
