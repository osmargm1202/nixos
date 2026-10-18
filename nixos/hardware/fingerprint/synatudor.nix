# Experimental native Synaptics Tudor MiS driver. Building these derivations
# does not install/start fprintd or access a real fingerprint reader.
{ pkgs }:
let
  driverSource = pkgs.fetchFromGitHub {
    owner = "vojtapl";
    repo = "libfprint";
    rev = "92c9c2b1c2f5ff41fdf6ed705143900a191e8a59";
    hash = "sha256-T+TMCdmphKkHzLpwnbf1pBNnHTMWVlDvgAsjoB5uUhA=";
  };
  researchSource = pkgs.fetchFromGitHub {
    owner = "vojtapl";
    repo = "synaTudorMiS";
    rev = "b700a346e735e429f757828bffe7fbbdaf9f9415";
    hash = "sha256-KbAkJP2FsoU4FnD/XPi/PGLQ7WXRla5QjHA146JTBYs=";
  };
  libfprint = pkgs.libfprint.overrideAttrs (old: {
    pname = "libfprint-synatudor";
    version = "1.94.9-unstable-2026-10-16";
    src = driverSource;
    # The fork includes its own driver/API changes; stable hardware-ID patches
    # are not applicable to this source tree. Retain upstream virtual drivers
    # and install checks so fprintd can be tested without physical hardware.
    patches = [ ];
    meta = old.meta // {
      homepage = "https://github.com/vojtapl/libfprint";
      description = "Experimental libfprint with Synaptics Tudor MiS (synatlsmoc) support";
    };
  });
  fprintd = (pkgs.fprintd.override { inherit libfprint; }).overrideAttrs (old: {
    pname = "fprintd-synatudor";
    # nixpkgs does not run this suite by default. Exercise the patched daemon
    # against virtual libfprint devices inside the Nix build sandbox.
    doCheck = true;
    patches = (old.patches or [ ]) ++ [
      "${researchSource}/libfprint/fprintd-load-store-persistent-data-from-device.patch"
      ./fprintd-tests-decode-errors.patch
    ];
    meta = old.meta // {
      description = "Experimental fprintd with Synaptics Tudor persistent pairing storage";
    };
  });
  probeSource = pkgs.replaceVars ./synatudor-probe.py {
    python = pkgs.python3;
    inherit fprintd;
    dbus = pkgs.dbus;
    # polkit's default output is "bin"; the daemon lives in "out".
    polkit = pkgs.polkit.out;
  };
  probe = pkgs.runCommand "envy-fingerprint-test" { } ''
    install -Dm755 ${probeSource} "$out/bin/envy-fingerprint-test"
    # Validate the substituted paths, not just the source placeholders. Loading
    # definitions does not invoke main(), D-Bus, polkit, or a fingerprint reader.
    ${pkgs.python3}/bin/python3 - "$out/bin/envy-fingerprint-test" <<'PY'
    import os, runpy, sys
    config = runpy.run_path(sys.argv[1])
    paths = [config['POLKIT'] / 'lib/polkit-1/polkitd',
             config['DBUS'] / 'bin/dbus-daemon',
             config['DBUS'] / 'bin/dbus-send',
             config['FPRINTD'] / 'libexec/fprintd']
    paths += [config['FPRINTD'] / 'bin' / name for name in
              ['fprintd-list', 'fprintd-enroll', 'fprintd-verify']]
    for path in paths:
        assert path.is_file() and os.access(path, os.X_OK), str(path)
    print('PASS: all private-probe runtime executables exist')
    PY
  '';
in
{
  inherit libfprint fprintd probe;
}
