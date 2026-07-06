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
  #
  # That alone didn't fix it: sddm-greeter-qt6 (the login UI, a separate
  # Wayland client process from kwin_wayland) logs "vaExportSurfaceHandle
  # failed" on NVIDIA — it's trying to hand KWin a hardware (VAAPI/dmabuf)
  # buffer for its surfaces, which fails silently, taking the cursor image
  # down with it. Force the greeter itself onto shm (software) buffers so
  # it never attempts that hardware export path.
  systemd.services.display-manager.environment = {
    KWIN_FORCE_SW_CURSOR = "1";
    QT_WAYLAND_CLIENT_BUFFER_INTEGRATION = "shm";
  };

  security.pam.services.sddm.enableGnomeKeyring = true;
}
