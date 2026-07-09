{ config, pkgs, inputs, ... }:

let
  hostThemeFile = ../hosts/${config.networking.hostName}/sddm-theme.nix;
  hostTheme = if builtins.pathExists hostThemeFile then import hostThemeFile else "clockwork";

  # Upstream's nixosModules.default hits the deprecated `pkgs.system` alias
  # (evaluation warning); call its builders directly until that's fixed.
  qylock = inputs.qylock.legacyPackages.${pkgs.stdenv.hostPlatform.system};
  sddmThemes = qylock.mkSddmThemes { themeOptions = { }; };
  qylockShell = qylock.mkQuickshell {
    defaultTheme = hostTheme;
    themeOptions = { };
  };
in
{
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
    theme = hostTheme;
    extraPackages = [
      sddmThemes
      # QML modules the themes import (e.g. Qt5Compat.GraphicalEffects).
      # extraPackages contributes lib/qt-6/qml to the greeter's QML_IMPORT_PATH.
      pkgs.qt6.qt5compat
      pkgs.qt6.qtmultimedia
      pkgs.qt6.qtsvg
    ];
  };

  environment.systemPackages = [
    sddmThemes
    qylockShell
  ];

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
