# Engram — memoria persistente local y compartida entre agentes mediante MCP.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  engram = pkgs.callPackage ../apps/engram.nix { };
in
{
  config = lib.mkIf (builtins.elem "ai" config.orgm.user.programs) {
    environment.systemPackages = [ engram ];
  };
}
