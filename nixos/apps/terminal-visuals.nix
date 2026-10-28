{ config, lib, pkgs, ... }:
{
  options.orgm.terminalVisuals.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Install rmatrix, Peaclock and CAVA on every host, without autostart.";
  };
  config = lib.mkIf config.orgm.terminalVisuals.enable {
    environment.systemPackages = [ (pkgs.callPackage ../packages/terminal-visuals.nix { }) ];
  };
}
