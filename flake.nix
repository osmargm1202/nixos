{
  description = "Modular NixOS flake for orgm";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-flatpak.url = "github:gmodena/nix-flatpak";
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
    waybar-source-target-src = {
      # Pending upstream support for pulseaudio source sliders.
      # PR: https://github.com/Alexays/Waybar/pull/4908
      url = "github:7FM/Waybar/ab5b1a6cd41d10da238e6ab5da32d798aa6ba04c";
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
    # flake.lock intentionally not updated in this branch; update after dotfiles helper branch lands.
    dotfiles-orgm-source = {
      url = "github:osmargm1202/dotfiles";
      flake = false;
    };
  };

  outputs =
    inputs@{ nixpkgs, ... }:
    let
      system = "x86_64-linux";
      # Generic profile outputs use eval-only hardware so pure flake checks do not
      # depend on /etc or any real host. Host-specific outputs pass real hardware.
      pkgs = nixpkgs.legacyPackages.${system};
      # During staged migration, verify unpublished dotfiles helper changes with:
      # --override-input dotfiles-orgm-source path:/path/to/dotfiles-worktree
      # Committed default uses the reproducible GitHub source below.
      dotfilesOrgmSource = inputs.dotfiles-orgm-source;
      orgmDot = pkgs.callPackage ./nixos/packages/orgm-dot.nix { inherit dotfilesOrgmSource; };
      orgmWallpaper = pkgs.callPackage ./nixos/packages/orgm-wallpaper.nix {
        inherit dotfilesOrgmSource;
      };
      orgmCalendar = pkgs.callPackage ./nixos/packages/orgm-calendar.nix { inherit dotfilesOrgmSource; };
      engram = pkgs.callPackage ./nixos/packages/engram.nix { };
      defaultHardware = ./nixos/hosts/generic/hardware-configuration.nix;
      profiles = {
        gnome = ./nixos/profiles/gnome.nix;
        hyprland = ./nixos/profiles/hyprland.nix;
        labwc = ./nixos/profiles/labwc.nix;
        labwc-light = ./nixos/profiles/labwc-light.nix;
        sway = ./nixos/profiles/sway.nix;
        i3 = ./nixos/profiles/i3.nix;
      };
      getProfile =
        profileName:
        profiles.${profileName}
          or (throw "Unknown ORGMOS profile '${profileName}'. Valid profiles: ${builtins.concatStringsSep ", " (builtins.attrNames profiles)}");
      mkHost =
        {
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
          ]
          ++ extraModules;
        };
      mkProfile =
        {
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
          ]
          ++ extraModules;
        };
      mkGeneralHost =
        {
          hardware,
          profile,
          hostName,
          extraModules ? [ ],
        }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            ./nixos/common.nix
            ./nixos/general.nix
            hardware
            (getProfile profile)
            { networking.hostName = hostName; }
          ]
          ++ extraModules;
        };
    in
    {
      lib = {
        inherit mkGeneralHost;
      };

      formatter.${system} = pkgs.nixfmt-rfc-style;

      packages.${system} = {
        inherit
          orgmDot
          orgmWallpaper
          orgmCalendar
          engram
          ;
        "orgm-dot" = orgmDot;
        "orgm-wallpaper" = orgmWallpaper;
        "orgm-calendar" = orgmCalendar;
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
