# Engram — memoria persistente local y compartida entre agentes mediante MCP.
{ pkgs, ... }:
let
  engram = pkgs.callPackage ../packages/engram.nix { };
in
{
  environment.systemPackages = [ engram ];
}
