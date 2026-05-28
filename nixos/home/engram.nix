{ pkgs, ... }:

let
  engram = pkgs.callPackage ../packages/engram.nix { };
in
{
  # First build is expected to fail with hash mismatches because the package uses
  # lib.fakeHash for src.hash and vendorHash. Replace both hashes with the values
  # reported by Nix, then rebuild.
  home.packages = [ engram ];
}
