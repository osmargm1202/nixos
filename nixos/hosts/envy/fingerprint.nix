{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.orgm.envy.fingerprint.experimental;
  packages = import ../../hardware/fingerprint/synatudor.nix { inherit pkgs; };
in
{
  options.orgm.envy.fingerprint.experimental.enable = lib.mkEnableOption ''
    the experimental synaTudorMiS backend for Envy's Synaptics 06cb:00c9.
    Opening the device may change its pairing; see docs/envy-fingerprint.md
    before enabling. This does not configure additional PAM authentication
  '';

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !config.services.fprintd.tod.enable;
        message = "Envy synaTudorMiS uses native libfprint, not a TOD driver.";
      }
    ];
    services.fprintd = {
      enable = true;
      package = packages.fprintd;
    };
    services.udev.packages = [ packages.libfprint ];
    warnings = [
      "Envy: experimental synaTudorMiS is enabled; opening the reader may replace its pairing. NixOS rollback cannot undo sensor changes."
    ];
  };
}
