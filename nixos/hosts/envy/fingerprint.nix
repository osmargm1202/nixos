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
    The saved pairing from the physical test is required; see
    docs/envy-fingerprint.md. Managed PAM services stay password-only;
    the independent Sway lock conversation is a separate opt-in
  '';

  # services.fprintd.enable normally enables fingerprint in every PAM service.
  # Extend its submodule type instead of enumerating service names (or mapping
  # config.security.pam.services onto itself, which would recurse). Qylock's
  # independent PAM configDirectory is not part of this managed attribute set.
  options.security.pam.services = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        config.fprintAuth = lib.mkIf cfg.enable (lib.mkForce false);
      }
    );
  };

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
    # The real host stalled opening after USB runtime suspend; keeping this
    # reader awake + restarting fprintd restored verify with the same pairing.
    # A narrow workaround, not a claim that every TLS stall has this cause.
    services.udev.extraRules = lib.mkAfter ''
      ACTION=="add|change", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="06cb", ATTR{idProduct}=="00c9", TEST=="power/control", ATTR{power/control}="on"
    '';
    systemd.services.fprintd = {
      serviceConfig = {
        # The packaged upstream unit already has StateDirectory=fprint. Reset
        # that list first or systemd would expose BOTH directories and the
        # daemon would select the empty standard one, triggering a new pairing.
        StateDirectory = lib.mkForce [
          ""
          "fprint-synatudor-test"
        ];
        StateDirectoryMode = "0700";
      };
      preStart = ''
        # Keep the validated pairing in place. No migration, deletion, or
        # creation of a new pairing on first boot / missing state.
        if [ "$STATE_DIRECTORY" != /var/lib/fprint-synatudor-test ]; then
          echo 'fprintd: refusing unexpected state directory; reader not opened' >&2
          exit 1
        fi
        found=
        for pairing in "$STATE_DIRECTORY"/0-persistent/synatlsmoc/*; do
          if [ -f "$pairing" ] && [ -s "$pairing" ]; then
            found=1
            break
          fi
        done
        if [ "$found" != 1 ]; then
          echo 'fprintd: saved Synaptics pairing missing; reader not opened. Do not reset/enroll again.' >&2
          exit 1
        fi
      '';
    };
    warnings = [
      "Envy: experimental synaTudorMiS reuses /var/lib/fprint-synatudor-test; keep this private state. Managed PAM remains password-only."
    ];
  };
}
