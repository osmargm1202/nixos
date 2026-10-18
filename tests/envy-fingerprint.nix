# Evaluation-only regression tests. No daemon, USB device, or PAM conversation
# is started. Run: nix eval --impure --json --file tests/envy-fingerprint.nix
let
  flake = builtins.getFlake (toString ../.);
  nixpkgs = flake.inputs.nixpkgs;
  pkgs = import nixpkgs { system = "x86_64-linux"; };
  packages = import ../nixos/hardware/fingerprint/synatudor.nix { inherit pkgs; };
  mkConfig =
    modules:
    (nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ../nixos/hosts/envy/fingerprint.nix
        {
          system.stateVersion = "26.05";
          services.fprintd.enable = true;
          security.pam.services = {
            sudo = { };
            sddm = { };
            polkit-1 = { };
            swaylock = { };
            arbitrary-custom-service.fprintAuth = true;
          };
        }
      ]
      ++ modules;
    }).config;
  disabled = mkConfig [ ];
  enabled = mkConfig [ { orgm.envy.fingerprint.experimental.enable = true; } ];
  conflict = mkConfig [
    {
      orgm.envy.fingerprint.experimental.enable = true;
      services.fprintd.tod = {
        enable = true;
        driver = pkgs.emptyDirectory;
      };
    }
  ];
  managedServices = [
    "sudo"
    "sddm"
    "login"
    "polkit-1"
    "swaylock"
    "arbitrary-custom-service"
  ];
  hasFingerprint = text: nixpkgs.lib.hasInfix "pam_fprintd.so" text;
in
assert !disabled.orgm.envy.fingerprint.experimental.enable;
assert disabled.services.fprintd.package == pkgs.fprintd;
assert !(builtins.elem packages.libfprint disabled.services.udev.packages);
assert enabled.services.fprintd.enable;
assert enabled.services.fprintd.package == packages.fprintd;
assert builtins.elem packages.libfprint enabled.services.udev.packages;
assert !enabled.services.fprintd.tod.enable;
assert builtins.all (
  service:
  !enabled.security.pam.services.${service}.fprintAuth
  && !hasFingerprint enabled.security.pam.services.${service}.text
  && nixpkgs.lib.hasInfix "pam_unix.so" enabled.security.pam.services.${service}.text
) managedServices;
assert hasFingerprint disabled.security.pam.services.sudo.text;
assert
  enabled.systemd.services.fprintd.serviceConfig.StateDirectory == [
    ""
    "fprint-synatudor-test"
  ];
assert nixpkgs.lib.hasInfix "0-persistent/synatlsmoc" enabled.systemd.services.fprintd.preStart;
assert nixpkgs.lib.hasInfix "STATE_DIRECTORY" enabled.systemd.services.fprintd.preStart;
assert nixpkgs.lib.hasInfix
  ''ATTR{idVendor}=="06cb", ATTR{idProduct}=="00c9", TEST=="power/control", ATTR{power/control}="on"''
  enabled.services.udev.extraRules;
assert !(nixpkgs.lib.hasInfix ''ATTR{idProduct}=="00c9"'' disabled.services.udev.extraRules);
assert nixpkgs.lib.hasInfix "StateDirectory=\nStateDirectory=fprint-synatudor-test"
  enabled.systemd.units."fprintd.service".text;
assert builtins.any (
  a: !a.assertion && a.message == "Envy synaTudorMiS uses native libfprint, not a TOD driver."
) conflict.assertions;
{
  defaultDisabled = true;
  stockBackendWhenDisabled = true;
  customDaemonAndUdevWhenEnabled = true;
  fingerprintDisabledInAllManagedPamServices = true;
  passwordRetained = true;
  validatedPairingStateReused = true;
  missingStateGuard = true;
  upstreamStateDirectoryListReset = true;
  sensorOnlyRuntimePowerQuirk = true;
  preStartScript = enabled.systemd.services.fprintd.preStart;
  todConflictRejected = true;
  libfprint = packages.libfprint.drvPath;
  fprintd = packages.fprintd.drvPath;
}
