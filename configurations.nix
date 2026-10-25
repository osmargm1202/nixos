# Canonical systems select one desktop per host; retain ORGM's Ryoku fallback.
let
  historical = import ./configurations-legacy.nix;
  jarqMultimedia = {
    role = "multimedia";
    hostName = "jarq";
    profileName = "multimedia";
    userName = "jarq";
    hardware = ./nixos/hosts/jarq/hardware-configuration.nix;
    extraModules = [ ./nixos/hosts/jarq/multimedia.nix ];
  };
in
{
  inherit (historical) profiles;
  aliases = { };
  configurations = {
    envy = historical.configurations.envy;
    lenovo = historical.configurations.lenovo-ryoku;
    orgm = historical.configurations.orgm-hyprland;
    orgm-ryoku = historical.configurations.orgm-ryoku;
    ero = historical.configurations.ero-i3;
    jarq = jarqMultimedia;
    jarq-multimedia = jarqMultimedia;
  };
}
