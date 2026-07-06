{ config, inputs, ... }:

let
  hostThemeFile = ../hosts/${config.networking.hostName}/sddm-theme.nix;
  hostTheme = if builtins.pathExists hostThemeFile then import hostThemeFile else "clockwork";
in
{
  imports = [ inputs.qylock.nixosModules.default ];

  services.displayManager.sddm = {
    enable = true;
    wayland = {
      enable = true;
      compositor = "kwin";
    };
    autoNumlock = true;
    enableHidpi = true;
    settings = {
      General.Numlock = "on";
    };
  };

  programs.qylock = {
    enable = true;
    theme = hostTheme;
  };

  security.pam.services.sddm.enableGnomeKeyring = true;
}
