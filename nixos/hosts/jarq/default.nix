{ userName ? "jarq", ... }:

{
  imports = [ ./base.nix ];

  services.libinput.enable = true;
  hardware.sensor.iio.enable = true;

  home-manager.users.${userName}.dconf.settings."org/gnome/desktop/a11y/applications" = {
    screen-keyboard-enabled = true;
  };
}
