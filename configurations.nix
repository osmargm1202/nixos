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
    thinkpad11e = {
      role = "desktop";
      hostName = "thinkpad11e";
      profileName = "i3";
      profile = ./nixos/profiles/i3/lightweight.nix;
      userName = "hm";
      hardware = ./nixos/hosts/thinkpad11e/hardware-configuration.nix;
      extraModules = [ ./nixos/hosts/thinkpad11e/default.nix ];
    };
    x13 = {
      role = "desktop";
      hostName = "x13";
      profileName = "gnome";
      profile = ./nixos/hosts/x13/gnome.nix;
      userName = "osmarg";
      hardware = ./nixos/hosts/x13/hardware-configuration.nix;
      extraModules = [ ./nixos/hosts/x13/default.nix ];
    };
    envy = historical.configurations.envy;
    lenovo = historical.configurations.lenovo-ryoku;
    lenovo-server = {
      role = "terminal";
      hostName = "lenovo";
      userName = "osmarg";
      hardware = ./nixos/hosts/lenovo/hardware-configuration.nix;
      extraModules = [ ./nixos/hosts/lenovo/server.nix ];
    };
    orgm = historical.configurations.orgm-hyprland;
    orgm-ryoku = historical.configurations.orgm-ryoku;
    ero = historical.configurations.ero-i3;
    jarq = jarqMultimedia;
    jarq-multimedia = jarqMultimedia;
  };
}
