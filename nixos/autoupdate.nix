# Weekly automatic system updates, extracted from common.nix.
# NOT imported by any host yet — add it to a host's extraModules (or to
# common.nix imports) once we decide which machines self-update:
#
#   extraModules = [ ./nixos/autoupdate.nix ... ];
{
  lib,
  userName ? "osmarg",
  ...
}:

{
  system.autoUpgrade = {
    enable = true;
    dates = "weekly";
    operation = "switch";
    randomizedDelaySec = "45min";
    allowReboot = false;
    flake = lib.mkDefault "/home/${userName}/Hobby/nixos";
    flags = [
      "--update-input"
      "nixpkgs"
      "--update-input"
      "home-manager"
      "-L"
    ];
  };
}
