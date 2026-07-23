# RTK — proxy de comandos con salida compacta para reducir el contexto consumido.
{ pkgs, ... }:
let
  rtk = pkgs.callPackage ../packages/rtk.nix { };
in
{
  environment.systemPackages = [ rtk ];
}
