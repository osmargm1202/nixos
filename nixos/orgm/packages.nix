{ pkgs }:
{
  orgmai = pkgs.callPackage ./orgm-ai.nix { };
  orgm-organize = pkgs.callPackage ./orgm-organize.nix { };
  orgm-rnc = pkgs.callPackage ./orgm-rnc.nix { };
  orgm-bt = pkgs.callPackage ./orgm-bt.nix { };
}
