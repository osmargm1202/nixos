{
  config,
  lib,
  pkgs,
  profileName ? null,
  ...
}:

let
  hostThemeFile = ../hosts/${config.networking.hostName}/sddm-theme.nix;
  hostTheme = if builtins.pathExists hostThemeFile then import hostThemeFile else "black_hole";
  useGreenShift = profileName == "hyprland";
  themePackage =
    if useGreenShift then
      pkgs.callPackage ../packages/sddm-greenshift.nix { }
    else
      pkgs.sddm-astronaut.override { embeddedTheme = hostTheme; };
in
{
  services.displayManager.sddm = {
    enable = true;
    package = pkgs.kdePackages.sddm;
    wayland.enable = true;
    autoNumlock = true;
    enableHidpi = true;
    settings.General.Numlock = "on";
    theme = if useGreenShift then "GreenShift" else "sddm-astronaut-theme";
    extraPackages =
      if useGreenShift then
        with pkgs.kdePackages;
        [
          qt5compat
          qtsvg
        ]
      else
        [ pkgs.kdePackages.qtmultimedia ];
    # GreenShift reads battery state from sysfs through QML XMLHttpRequest.
    settings.General.GreeterEnvironment = lib.mkIf useGreenShift (
      lib.concatStringsSep "," (
        [ "QML_XHR_ALLOW_FILE_READ=1" ]
        ++ lib.optional (
          config.services.displayManager.sddm.wayland.compositor == "kwin"
        ) "QT_WAYLAND_SHELL_INTEGRATION=layer-shell"
      )
    );
  };

  environment.systemPackages = [ themePackage ];

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
