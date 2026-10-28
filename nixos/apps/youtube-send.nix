# Direct HTTPS sender with its own persistent approval; no browser dependency.
{ inputs, pkgs, ... }:
let
  app = pkgs.callPackage "${inputs.orgm-multimedia}/package.nix" { };
in
{
  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "orgm-send-youtube";
      runtimeInputs = [ pkgs.wl-clipboard pkgs.xclip pkgs.libnotify ];
      text = ''
        exec ${app}/bin/orgm-send-youtube "$@"
      '';
    })
  ];
}
