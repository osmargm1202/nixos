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
            swaylock = { };
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
  pamUnchanged =
    service:
    enabled.security.pam.services.${service}.text
    == builtins.replaceStrings [ "${pkgs.fprintd}" ] [ "${packages.fprintd}" ]
      disabled.security.pam.services.${service}.text;
in
assert !disabled.orgm.envy.fingerprint.experimental.enable;
assert disabled.services.fprintd.package == pkgs.fprintd;
assert !(builtins.elem packages.libfprint disabled.services.udev.packages);
assert enabled.services.fprintd.enable;
assert enabled.services.fprintd.package == packages.fprintd;
assert builtins.elem packages.libfprint enabled.services.udev.packages;
assert !enabled.services.fprintd.tod.enable;
assert builtins.all
  (
    service:
    pamUnchanged service
    &&
      nixpkgs.lib.hasInfix
        (builtins.unsafeDiscardStringContext "${packages.fprintd}/lib/security/pam_fprintd.so")
        enabled.security.pam.services.${service}.text
    && nixpkgs.lib.hasInfix "pam_unix.so" enabled.security.pam.services.${service}.text
  )
  [
    "sudo"
    "sddm"
    "swaylock"
  ];
assert builtins.any (
  a: !a.assertion && a.message == "Envy synaTudorMiS uses native libfprint, not a TOD driver."
) conflict.assertions;
{
  defaultDisabled = true;
  stockBackendWhenDisabled = true;
  customDaemonAndUdevWhenEnabled = true;
  pamPolicyUnchanged = true;
  todConflictRejected = true;
  libfprint = packages.libfprint.drvPath;
  fprintd = packages.fprintd.drvPath;
}
