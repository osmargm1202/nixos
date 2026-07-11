{ config, pkgs, ... }:

let
  hostThemeFile = ../hosts/${config.networking.hostName}/sddm-theme.nix;
  hostTheme = if builtins.pathExists hostThemeFile then import hostThemeFile else "black_hole";
in
{
  services.displayManager.sddm = {
    enable = true;
    package = pkgs.kdePackages.sddm;
    wayland.enable = true;
    autoNumlock = true;
    enableHidpi = true;
    settings.General.Numlock = "on";
    theme = "sddm-astronaut-theme";
    extraPackages = with pkgs; [ kdePackages.qtmultimedia ];
  };

  environment.systemPackages = [
    (pkgs.sddm-astronaut.override { embeddedTheme = hostTheme; })
  ];

  # NVIDIA + KWin Wayland: hardware cursor plane no compone en NVIDIA.
  # KWIN_FORCE_SW_CURSOR fuerza KWin a dibujar el cursor via software.
  # QT_WAYLAND_CLIENT_BUFFER_INTEGRATION=shm evita que el greeter intente
  # exportar buffers VAAPI/dmabuf hacia KWin (que falla silenciosamente
  # en NVIDIA y se lleva el cursor con ella).
  systemd.services.display-manager.environment = {
    KWIN_FORCE_SW_CURSOR = "1";
    QT_WAYLAND_CLIENT_BUFFER_INTEGRATION = "shm";
  };

  security.pam.services.sddm.enableGnomeKeyring = true;
}
