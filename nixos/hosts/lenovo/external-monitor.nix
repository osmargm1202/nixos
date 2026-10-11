{ pkgs, ... }:
let
  helper = pkgs.writeShellApplication {
    name = "lenovo-external-monitor";
    runtimeInputs = [
      pkgs.jq
      pkgs.xrandr
      pkgs.wlr-randr
    ];
    text = builtins.readFile ./external-monitor.sh;
  };
in
{
  environment.systemPackages = [ helper ];
  system.build.lenovoExternalMonitor = helper;
}
