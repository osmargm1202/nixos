let
  genericHardware = ./nixos/hosts/generic/hardware-configuration.nix;

  profiles = {
    cinnamon = ./nixos/profiles/cinnamon.nix;
    gnome = ./nixos/profiles/gnome.nix;
    hyprland = ./nixos/profiles/hyprland.nix;
    i3 = ./nixos/profiles/i3.nix;
    labwc = ./nixos/profiles/labwc.nix;
  };

  desktop =
    {
      profileName,
      hostName ? "nixos",
      hardware ? genericHardware,
      userName ? "osmarg",
      extraModules ? [ ],
    }:
    {
      role = "desktop";
      inherit
        hostName
        hardware
        userName
        extraModules
        profileName
        ;
      profile = profiles.${profileName};
    };

  terminal =
    {
      hostName ? "nixos",
      hardware ? genericHardware,
      userName ? "osmarg",
      extraModules ? [ ],
    }:
    {
      role = "terminal";
      inherit
        hostName
        hardware
        userName
        extraModules
        ;
    };

  server =
    {
      hostName ? "nixos",
      hardware ? genericHardware,
      userName ? "osmarg",
      extraModules ? [ ],
    }:
    {
      role = "server";
      inherit
        hostName
        hardware
        userName
        extraModules
        ;
    };

  jarqExtra = [
    ./nixos/hardware/gpu/intel.nix
    ./nixos/hosts/jarq/default.nix
  ];
  orgmExtra = [
    ./nixos/hardware/gpu/nvidia.nix
    ./nixos/hosts/orgm/ms-7d43.nix
    ./nixos/gaming/default.nix
  ];
  lenovoExtra = [
    ./nixos/hosts/lenovo/p14s-gen2i.nix
    ./nixos/hosts/lenovo/audio.nix
    ./nixos/gaming/steam.nix
    ./nixos/gaming/emulators.nix
  ];
in
{
  inherit profiles;

  aliases = {
    orgm = "orgm-hyprland";
    lenovo = "lenovo-hyprland";
    jarq = "jarq-hyprland";
  };

  configurations = {
    cinnamon = desktop { profileName = "cinnamon"; };
    gnome = desktop { profileName = "gnome"; };
    hyprland = desktop { profileName = "hyprland"; };
    i3 = desktop { profileName = "i3"; };
    labwc = desktop { profileName = "labwc"; };
    terminal = terminal { };
    server = server { };

    jarq-server = server {
      hostName = "jarq";
      hardware = ./nixos/hosts/jarq/hardware-configuration.nix;
      userName = "osmarg";
      extraModules = [
        ./nixos/hardware/gpu/intel.nix
        ./nixos/hosts/jarq/server.nix
        ./server/modules
      ];
    };
    jarq-terminal = terminal {
      hostName = "jarq";
      hardware = ./nixos/hosts/jarq/hardware-configuration.nix;
      userName = "jarq";
    };
    jarq-i3 = desktop {
      hostName = "jarq";
      hardware = ./nixos/hosts/jarq/hardware-configuration.nix;
      profileName = "i3";
      userName = "jarq";
      extraModules = jarqExtra;
    };
    jarq-labwc = desktop {
      hostName = "jarq";
      hardware = ./nixos/hosts/jarq/hardware-configuration.nix;
      profileName = "labwc";
      userName = "jarq";
      extraModules = jarqExtra;
    };
    jarq-hyprland = desktop {
      hostName = "jarq";
      hardware = ./nixos/hosts/jarq/hardware-configuration.nix;
      profileName = "hyprland";
      userName = "jarq";
      extraModules = jarqExtra;
    };

    orgm-terminal = terminal {
      hostName = "orgm";
      hardware = ./nixos/hosts/orgm/hardware-configuration.nix;
    };
    orgm-gnome = desktop {
      hostName = "orgm";
      hardware = ./nixos/hosts/orgm/hardware-configuration.nix;
      profileName = "gnome";
      extraModules = orgmExtra;
    };
    orgm-cinnamon = desktop {
      hostName = "orgm";
      hardware = ./nixos/hosts/orgm/hardware-configuration.nix;
      profileName = "cinnamon";
      extraModules = orgmExtra;
    };
    orgm-hyprland = desktop {
      hostName = "orgm";
      hardware = ./nixos/hosts/orgm/hardware-configuration.nix;
      profileName = "hyprland";
      extraModules = orgmExtra;
    };
    orgm-labwc = desktop {
      hostName = "orgm";
      hardware = ./nixos/hosts/orgm/hardware-configuration.nix;
      profileName = "labwc";
      extraModules = orgmExtra;
    };
    orgm-i3 = desktop {
      hostName = "orgm";
      hardware = ./nixos/hosts/orgm/hardware-configuration.nix;
      profileName = "i3";
      extraModules = orgmExtra;
    };
    ero-terminal = terminal {
      hostName = "ero";
      hardware = ./nixos/hosts/ero/hardware-configuration.nix;
    };
    ero-labwc = desktop {
      hostName = "ero";
      hardware = ./nixos/hosts/ero/hardware-configuration.nix;
      profileName = "labwc";
      extraModules = [ ./nixos/hardware/gpu/intel.nix ];
    };
    ero-i3 = desktop {
      hostName = "ero";
      hardware = ./nixos/hosts/ero/hardware-configuration.nix;
      profileName = "i3";
      extraModules = [ ./nixos/hardware/gpu/intel.nix ];
    };
    ero-server = server {
      hostName = "ero";
      hardware = ./nixos/hosts/ero/hardware-configuration.nix;
    };

    lenovo-terminal = terminal {
      hostName = "lenovo";
      hardware = ./nixos/hosts/lenovo/hardware-configuration.nix;
    };
    lenovo-labwc = desktop {
      hostName = "lenovo";
      hardware = ./nixos/hosts/lenovo/hardware-configuration.nix;
      profileName = "labwc";
      extraModules = lenovoExtra;
    };
    lenovo-gnome = desktop {
      hostName = "lenovo";
      hardware = ./nixos/hosts/lenovo/hardware-configuration.nix;
      profileName = "gnome";
      extraModules = lenovoExtra;
    };
    lenovo-hyprland = desktop {
      hostName = "lenovo";
      hardware = ./nixos/hosts/lenovo/hardware-configuration.nix;
      profileName = "hyprland";
      extraModules = lenovoExtra;
    };
    lenovo-i3 = desktop {
      hostName = "lenovo";
      hardware = ./nixos/hosts/lenovo/hardware-configuration.nix;
      profileName = "i3";
      extraModules = lenovoExtra;
    };
  };
}
