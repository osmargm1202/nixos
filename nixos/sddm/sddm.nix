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
  defaultProfile =
    if builtins.elem profileName [
      "hyprland"
      "i3"
    ] then
      "greenshift"
    else
      "astronaut";
in
{
  imports = [
    ./sddm-profile-greenshift.nix
    ./sddm-profile-astronaut.nix
    ./sddm-profile-qylock.nix
  ];

  options.orgm.sddm = {
    profile = lib.mkOption {
      type = lib.types.enum [
        "greenshift"
        "astronaut"
        "qylock"
      ];
      default = defaultProfile;
      description = "SDDM theme profile.";
    };

    qylockTheme = lib.mkOption {
      type = lib.types.enum [
        "winter"
        "star-rail"
        "forest"
        "sword"
        "wuthering-waves"
        "clockwork"
        "last-of-us"
        "nier-automata"
        "Genshin"
        "minecraft"
        "material-you-dark"
      ];
      default = "winter";
      description = "Installed Qylock SDDM theme.";
    };
  };

  config = {
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
    };

    environment.systemPackages = [ cursorPackage ];

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
  };
}
