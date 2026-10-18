# Evaluate the actual Envy configuration, including its boot specialisations.
# No service, PAM conversation, or physical reader is started.
# nix eval --impure --json --file tests/envy-fingerprint-host.nix
let
  flake = builtins.getFlake ("path:" + toString ../.);
  lib = flake.inputs.nixpkgs.lib;
  config = flake.nixosConfigurations.envy.config;
  services = config.security.pam.services;
  passwordOnly = c: builtins.all (service:
    !service.fprintAuth && !lib.hasInfix "pam_fprintd.so" service.text
  ) (builtins.attrValues c.security.pam.services);
  runtime = builtins.head (builtins.filter (p: (p.pname or "") == "orgm-qylock")
    config.environment.systemPackages);
in
assert config.orgm.envy.fingerprint.experimental.enable;
assert config.orgm.sway.fingerprint.enable;
assert builtins.elem "/share/orgm-qylock" config.environment.pathsToLink;
assert config.services.fprintd.package.pname == "fprintd-synatudor";
assert passwordOnly config;
assert builtins.all (s: passwordOnly s.configuration)
  (builtins.attrValues config.specialisation);
assert lib.hasInfix "pam_unix.so" services.sudo.text;
assert lib.hasInfix "pam_unix.so" services.login.text;
assert lib.hasInfix "pam_unix.so" services.polkit-1.text;
assert lib.hasInfix "auth substack login" services.sddm.text;
assert config.systemd.services.fprintd.serviceConfig.StateDirectory == [ "" "fprint-synatudor-test" ];
assert lib.hasInfix "StateDirectory=\nStateDirectory=fprint-synatudor-test"
  config.systemd.units."fprintd.service".text;
assert builtins.all (a: a.assertion) config.assertions;
{
  hostAndLockOptIn = true;
  managedPamPasswordOnly = true;
  systemRuntimeMetadataExported = true;
  specialisationsPasswordOnly = true;
  existingStateReused = true;
  backend = config.services.fprintd.package.outPath;
  lockRuntime = runtime.outPath;
  managedPamServiceCount = builtins.length (builtins.attrNames services);
}
