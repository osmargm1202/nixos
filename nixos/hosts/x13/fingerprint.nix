# Goodix 27c6:6594 uses the stock libfprint Goodix MOC driver.
{ config, lib, ... }:
{
  # Enabling fprintd otherwise enables the generic fingerprint PAM rule in
  # every service. GDM has a dedicated parallel gdm-fingerprint conversation;
  # enable the requested sudo/polkit uses while keeping SSH/console password-only.
  options.security.pam.services = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
      config.fprintAuth = lib.mkForce (
        config.services.fprintd.enable && builtins.elem name [ "sudo" "polkit-1" ]
      );
    }));
  };
  config = {
    services.fprintd.enable = config.services.displayManager.gdm.enable;
    assertions = [ {
      assertion = !config.services.fprintd.tod.enable;
      message = "X13 Goodix 27c6:6594 uses the stock libfprint driver, not a TOD or Envy Synaptics backend.";
    } ];
  };
}
