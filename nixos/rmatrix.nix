{
  lib,
  pkgs,
  ...
}:
let
  rmatrix = pkgs.stdenvNoCC.mkDerivation {
    pname = "rmatrix";
    version = "0.1.1";

    src = pkgs.fetchurl {
      url = "https://github.com/osmargm1202/rmatrix/releases/download/v0.1.1/rmatrix-v0.1.1-x86_64-linux.tar.gz";
      hash = "sha256-3O5dzYvyNZe0vHcwmYPc2qZY5FvyAOTnTJ5+6dxv9jw=";
    };

    dontUnpack = true;
    nativeBuildInputs = [ pkgs.gnutar ];

    installPhase = ''
      tar -xzf "$src"
      install -Dm755 rmatrix "$out/bin/rmatrix"
    '';

    meta = {
      description = "Digital rain for modern terminals";
      homepage = "https://github.com/osmargm1202/rmatrix";
      license = lib.licenses.mit;
      mainProgram = "rmatrix";
      platforms = [ "x86_64-linux" ];
    };
  };
in
{
  environment.systemPackages = [ rmatrix ];
}
