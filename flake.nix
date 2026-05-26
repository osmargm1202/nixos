{
  description = "Modular NixOS flake for orgm";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprland = {
      # Track latest upstream git. Pin exact rev in flake.lock for reproducible builds.
      url = "git+https://github.com/hyprwm/Hyprland?submodules=1";
    };
    hyprpaper = {
      # Keep hyprpaper IPC compatible with latest Hyprland/hyprctl.
      url = "github:hyprwm/hyprpaper";
    };
    nwg-dock-hyprland-src = {
      # Track upstream git so dock focus behavior can follow Hyprland changes.
      url = "github:nwg-piotr/nwg-dock-hyprland";
      flake = false;
    };
    snappy-switcher.url = "github:OpalAayan/snappy-switcher";
    caelestia-shell = {
      url = "github:caelestia-dots/shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dms = {
      url = "github:AvengeMedia/DankMaterialShell/stable";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dgop = {
      url = "github:AvengeMedia/dgop";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sddm-astronaut-theme = {
      url = "github:Keyitdev/sddm-astronaut-theme";
      flake = false;
    };
    ltmnight-sddm-theme = {
      url = "github:osmargm1202/ltmnight-sddm-theme";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };


  outputs = inputs@{ nixpkgs, ... }: let
    system = "x86_64-linux";
    # Generic profile outputs use eval-only hardware so pure flake checks do not
    # depend on /etc or any real host. Host-specific outputs pass real hardware.
    pkgs = nixpkgs.legacyPackages.${system};
    orgmDot = pkgs.callPackage ./nixos/packages/orgm-dot.nix { };
    orgmHypr = pkgs.callPackage ./nixos/packages/orgm-hypr.nix { };
    defaultHardware = ./nixos/hosts/generic/hardware-configuration.nix;
    mkHost = {
      hostName,
      hardware,
      profile,
      extraModules ? [ ],
    }:
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          ./nixos/common.nix
          hardware
          profile
          { networking.hostName = hostName; }
        ] ++ extraModules;
      };
    mkProfile = {
      profile,
      hostName ? "nixos",
      extraModules ? [ ],
    }:
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          ./nixos/common.nix
          defaultHardware
          profile
          { networking.hostName = hostName; }
        ] ++ extraModules;
      };
  in {
    formatter.${system} = pkgs.nixfmt-rfc-style;

    packages.${system} = {
      inherit orgmDot orgmHypr;
      "orgm-dot" = orgmDot;
      "orgm-hypr" = orgmHypr;
      default = orgmDot;
    };

    nixosConfigurations = {
      gnome = mkProfile {
        profile = ./nixos/profiles/gnome.nix;
      };
      hyprland = mkProfile {
        profile = ./nixos/profiles/hyprland.nix;
      };

      labwc = mkProfile {
        profile = ./nixos/profiles/labwc.nix;
      };
      labwc-light = mkProfile {
        profile = ./nixos/profiles/labwc-light.nix;
      };
      sway = mkProfile {
        profile = ./nixos/profiles/sway.nix;
      };
      i3 = mkProfile {
        profile = ./nixos/profiles/i3.nix;
      };
      orgm-gnome = mkHost {
        hostName = "orgm";
        hardware = ./nixos/hosts/orgm/hardware-configuration.nix;
        profile = ./nixos/profiles/gnome.nix;
        extraModules = [
          ./nixos/hosts/orgm/plymouth.nix
          ./nixos/gaming/default.nix
        ];
      };
      orgm-hyprland = mkHost {
        hostName = "orgm";
        hardware = ./nixos/hosts/orgm/hardware-configuration.nix;
        profile = ./nixos/profiles/hyprland.nix;
        extraModules = [
          ./nixos/hosts/orgm/plymouth.nix
          ./nixos/gaming/default.nix
        ];
      };

      orgm-labwc = mkHost {
        hostName = "orgm";
        hardware = ./nixos/hosts/orgm/hardware-configuration.nix;
        profile = ./nixos/profiles/labwc.nix;
        extraModules = [
          ./nixos/hosts/orgm/plymouth.nix
          ./nixos/gaming/default.nix
        ];
      };
      orgm-sway = mkHost {
        hostName = "orgm";
        hardware = ./nixos/hosts/orgm/hardware-configuration.nix;
        profile = ./nixos/profiles/sway.nix;
        extraModules = [
          ./nixos/hosts/orgm/plymouth.nix
          ./nixos/gaming/default.nix
        ];
      };

      ero-labwc = mkHost {
        hostName = "ero";
        hardware = ./nixos/hosts/ero/hardware-configuration.nix;
        profile = ./nixos/profiles/labwc.nix;
        extraModules = [ ./nixos/hosts/ero/plymouth.nix ];
      };
      ero-i3 = mkHost {
        hostName = "ero";
        hardware = ./nixos/hosts/ero/hardware-configuration.nix;
        profile = ./nixos/profiles/i3.nix;
        extraModules = [ ./nixos/hosts/ero/plymouth.nix ];
      };
      ero-sway = mkHost {
        hostName = "ero";
        hardware = ./nixos/hosts/ero/hardware-configuration.nix;
        profile = ./nixos/profiles/sway.nix;
        extraModules = [ ./nixos/hosts/ero/plymouth.nix ];
      };
      ero-server = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          ./nixos/hosts/ero/hardware-configuration.nix
          ./nixos/server.nix
          { networking.hostName = "ero"; }
        ];
      };

      lenovo-labwc = mkHost {
        hostName = "lenovo";
        hardware = ./nixos/hosts/lenovo/hardware-configuration.nix;
        profile = ./nixos/profiles/labwc.nix;
        extraModules = [
          ./nixos/hosts/lenovo/plymouth.nix
          ./nixos/hosts/lenovo/audio.nix
          ./nixos/gaming/steam.nix
          ./nixos/gaming/emulators.nix
        ];
      };
      lenovo-gnome = mkHost {
        hostName = "lenovo";
        hardware = ./nixos/hosts/lenovo/hardware-configuration.nix;
        profile = ./nixos/profiles/gnome.nix;
        extraModules = [
          ./nixos/hosts/lenovo/plymouth.nix
          ./nixos/hosts/lenovo/audio.nix
          ./nixos/gaming/steam.nix
          ./nixos/gaming/emulators.nix
        ];
      };
      lenovo-hyprland = mkHost {
        hostName = "lenovo";
        hardware = ./nixos/hosts/lenovo/hardware-configuration.nix;
        profile = ./nixos/profiles/hyprland.nix;
        extraModules = [
          ./nixos/hosts/lenovo/plymouth.nix
          ./nixos/hosts/lenovo/audio.nix
          ./nixos/gaming/steam.nix
          ./nixos/gaming/emulators.nix
        ];
      };

      lenovo-sway = mkHost {
        hostName = "lenovo";
        hardware = ./nixos/hosts/lenovo/hardware-configuration.nix;
        profile = ./nixos/profiles/sway.nix;
        extraModules = [
          ./nixos/hosts/lenovo/plymouth.nix
          ./nixos/hosts/lenovo/audio.nix
          ./nixos/gaming/steam.nix
          ./nixos/gaming/emulators.nix
        ];
      };
    };
  };
}
