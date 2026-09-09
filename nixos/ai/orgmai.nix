# OrgM AI includes its own pinned Pi runtime; pi-install remains independent.
{ pkgs, ... }:
{
  environment.systemPackages = [ (pkgs.callPackage ../apps/orgmai.nix { }) ];
}
