{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Optional launchers/frontends; import this module only on hosts that need them.
    # lutris
    # heroic
    # bottles
    # retroarch
  ];
}
