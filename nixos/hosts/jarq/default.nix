{
  lib,
  options,
  userName ? "jarq",
  ...
}:

{
  imports = [ ./base.nix ];

  config = {
    services.libinput.enable = true;
    hardware.sensor.iio.enable = true;
  }
  // lib.optionalAttrs (options ? home-manager) {
    home-manager.users.${userName}.dconf.settings."org/gnome/desktop/a11y/applications" = {
      screen-keyboard-enabled = true;
    };
  };
}
