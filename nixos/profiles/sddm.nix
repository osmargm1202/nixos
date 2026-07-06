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

  # NVIDIA + KWin Wayland fails to composite the hardware cursor plane --
  # click position works but the pointer image never renders. Force KWin
  # to draw the cursor itself instead of relying on the hardware overlay.
  systemd.services.display-manager.environment.KWIN_FORCE_SW_CURSOR = "1";

  security.pam.services.sddm.enableGnomeKeyring = true;
}
