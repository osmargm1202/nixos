{
  config,
  lib,
  pkgs,
  ...
}:
let
  rmatrix = pkgs.callPackage ../packages/rmatrix.nix { };
in
{
  config = lib.mkIf (builtins.elem "rmatrix" config.orgm.user.programs) {
    environment.systemPackages = [ rmatrix ];
  };
}
