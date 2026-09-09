{ pkgs, ... }:
{
  # OrgM AI uses the native Pi installation and its normal credential flow.
  # Include its runtime and installer for server roles as well as desktops.
  imports = [ ../ai/pi.nix ];

  environment.systemPackages = builtins.attrValues (import ./packages.nix { inherit pkgs; });
}
