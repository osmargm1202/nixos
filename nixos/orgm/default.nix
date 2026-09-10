{ lib, pkgs, ... }:
{
  # OrgM AI uses the native Pi installation and its normal credential flow.
  # Include its runtime and installer for server roles as well as desktops.
  imports = [ ../ai/pi.nix ];

  # OrgM Todo is PolyForm Noncommercial. Authorize only this package so server
  # roles can include the shared OrgM tool collection without enabling unfree
  # software generally.
  nixpkgs.config.allowUnfreePredicate = package:
    lib.getName package == "orgm-todo";

  environment.systemPackages = builtins.attrValues (import ./packages.nix { inherit pkgs; });
}
