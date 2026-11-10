# Share one declarative wallpaper between Osmarg's desktop/lock screen and GDM.
{ config, lib, pkgs, userName, ... }:
let
  source = "${pkgs.gnome-backgrounds}/share/backgrounds/gnome/amber-d.jxl";
  image = pkgs.runCommand "x13-shared-wallpaper" { nativeBuildInputs = [ pkgs.libjxl ]; } ''
    mkdir -p "$out"
    djxl ${source} "$out/background.png"
  '';
  uri = "file://${image}/background.png";
  # GLib resource overlays replace just the two CSS files, with the original
  # Shell styles preserved. No patched Shell executable or authentication code.
  theme = pkgs.runCommand "x13-gdm-wallpaper" { nativeBuildInputs = [ pkgs.glib ]; } ''
    mkdir -p "$out"
    for variant in dark light; do
      css="gnome-shell-$variant.css"
      gresource extract ${pkgs.gnome-shell}/share/gnome-shell/gnome-shell-theme.gresource \
        "/org/gnome/shell/theme/$css" > "$out/$css"
      cat >> "$out/$css" <<'CSS'

    /* X13: same image as the desktop. Leave high contrast untouched. */
    #lockDialogGroup {
      background-color: #222226;
      background-image: url("${uri}");
      background-position: center;
      background-size: cover;
      background-repeat: no-repeat;
    }
    CSS
    done
  '';
in {
  # Apply only to the GDM instance, never the user's org.gnome.Shell@user unit.
  systemd.user.services."org.gnome.Shell@gdm" = lib.mkIf config.services.displayManager.gdm.enable {
    overrideStrategy = "asDropin";
    restartIfChanged = false;
    # A drop-in must inherit the greeter's environment, including PATH.
    environment = lib.mkForce {};
    serviceConfig.Environment = "G_RESOURCE_OVERLAYS=/org/gnome/shell/theme=${theme}";
  };
  home-manager.users.${userName}.dconf.settings = {
    "org/gnome/desktop/background" = {
      picture-uri = uri;
      picture-uri-dark = uri;
      picture-options = "zoom";
    };
    "org/gnome/desktop/screensaver".picture-uri = uri;
  };
}
