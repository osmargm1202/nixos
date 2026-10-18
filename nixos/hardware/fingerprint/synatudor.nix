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
in
{
  inherit libfprint fprintd;
}
