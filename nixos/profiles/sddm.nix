{
  config,
  lib,
  pkgs,
  profileName ? null,
  ...
}:

let
  cursorPackage = pkgs.catppuccin-cursors.macchiatoTeal;
  cursorTheme = "catppuccin-macchiato-teal-cursors";
  hostThemeFile = ../hosts/${config.networking.hostName}/sddm-theme.nix;
  hostTheme = if builtins.pathExists hostThemeFile then import hostThemeFile else "black_hole";
  useGreenShift = builtins.elem profileName [
    "hyprland"
    "i3"
  ];
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
    # The software-cursor workaround below requires KWin, not default Weston.
    wayland.compositor = "kwin";
    autoNumlock = true;
    enableHidpi = true;
    settings.General.Numlock = "on";
    settings.Theme = {
      CursorTheme = cursorTheme;
      CursorSize = 24;
    };
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
          config.services.displayManager.sddm.wayland.enable
          && config.services.displayManager.sddm.wayland.compositor == "kwin"
        ) "QT_WAYLAND_SHELL_INTEGRATION=layer-shell"
      )
    );
  };

  environment.systemPackages = [
    themePackage
    cursorPackage
  ];

  # NVIDIA + KWin Wayland: hardware cursor plane no compone en NVIDIA.
  # KWIN_FORCE_SW_CURSOR fuerza KWin a dibujar el cursor via software.
  # QT_WAYLAND_CLIENT_BUFFER_INTEGRATION=shm evita que el greeter intente
  # exportar buffers VAAPI/dmabuf hacia KWin (que falla silenciosamente
  # en NVIDIA y se lleva el cursor con ella).
  systemd.services.display-manager.environment = lib.mkIf config.services.displayManager.sddm.wayland.enable {
    # The sddm user has no Home Manager cursor configuration or icon search path.
    XCURSOR_THEME = cursorTheme;
    XCURSOR_SIZE = "24";
    XCURSOR_PATH = "${cursorPackage}/share/icons";
    KWIN_FORCE_SW_CURSOR = "1";
    QT_WAYLAND_CLIENT_BUFFER_INTEGRATION = "shm";
  };

  security.pam.services.sddm.enableGnomeKeyring = true;
}
