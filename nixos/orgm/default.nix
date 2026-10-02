{
  config,
  lib,
  pkgs,
  ...
}:
{
  # OrgM AI uses the native Pi installation and its normal credential flow.
  imports = [ ../ai/pi.nix ];

  config = lib.mkIf (builtins.elem "orgm" config.orgm.user.programs) {
    # OrgM Todo is PolyForm Noncommercial. Authorize only this package instead
    # of enabling unfree software for every user and role.
    nixpkgs.config.allowUnfreePredicate = package:
      lib.getName package == "orgm-todo";

    environment.systemPackages = builtins.attrValues (import ./packages.nix { inherit pkgs; });
  };
}
