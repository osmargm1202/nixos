# Uses the authorized default browser; never copies its cookies or room secret.
{ inputs, pkgs, ... }:
let
  app = pkgs.callPackage "${inputs.orgm-multimedia}/package.nix" { };
in
{
  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "orgm-send-youtube";
      runtimeInputs = [ pkgs.wl-clipboard pkgs.xclip pkgs.xdg-utils pkgs.libnotify ];
      text = ''
        exec ${app}/bin/orgm-send-youtube "$@"
      '';
    })
  ];
}
