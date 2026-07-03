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
      url = "github:dim-ghub/caelestia-shell";
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
    zen-browser-flake = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence.url = "github:nix-community/impermanence";
  };

  outputs =
    inputs@{ nixpkgs, ... }:
    let
      system = "x86_64-linux";
      # Generic profile outputs use eval-only hardware so pure flake checks do not
      # depend on /etc or any real host. Host-specific outputs pass real hardware.
      pkgs = nixpkgs.legacyPackages.${system};
      # Separate pkgs instance with allowUnfree for devShells (nix develop does not
      # inherit nixpkgs.config from NixOS modules — needs explicit config here).
      pkgsDev = import nixpkgs { inherit system; config.allowUnfree = true; };
      dotfilesOrgmSource = ./dotfiles;
      orgmDot = pkgs.callPackage ./nixos/packages/orgm-dot.nix { inherit dotfilesOrgmSource; };
      orgmWallpaper = pkgs.callPackage ./nixos/packages/orgm-wallpaper.nix {
        inherit dotfilesOrgmSource;
      };
      orgmThemes = pkgs.callPackage ./nixos/packages/orgm-themes.nix { inherit dotfilesOrgmSource; };
      codebaseMcp = pkgs.callPackage ./nixos/packages/codebase-memory-mcp.nix { };
      defaultHardware = ./nixos/hosts/generic/hardware-configuration.nix;
      profiles = {
        cinnamon = ./nixos/profiles/cinnamon.nix;
        gnome = ./nixos/profiles/gnome.nix;
        hyprland = ./nixos/profiles/hyprland.nix;
        hyprlandqs-caelestia = ./nixos/profiles/hyprlandqs-caelestia.nix;
        labwc = ./nixos/profiles/labwc.nix;
        i3 = ./nixos/profiles/i3.nix;
        xfce = ./nixos/profiles/xfce.nix;
        mate = ./nixos/profiles/mate.nix;
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
          profileName,
          extraModules ? [ ],
          userName ? "osmarg",
        }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs userName profileName; };
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
          profileName,
          hostName ? "nixos",
          extraModules ? [ ],
          userName ? "osmarg",
        }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs userName profileName; };
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
          userName ? "osmarg",
        }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs userName; };
          modules = [
            ./nixos/common.nix
            ./nixos/general.nix
            hardware
            (getProfile profile)
            { networking.hostName = hostName; }
          ]
          ++ extraModules;
        };
      mkServerHost =
        {
          hardware,
          hostName,
          extraModules ? [ ],
          userName ? "osmarg",
        }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs userName; };
          modules = [
            hardware
            ./nixos/server.nix
            { networking.hostName = hostName; }
          ]
          ++ extraModules;
        };
      mkMinimalHost =
        {
          hardware,
          hostName,
          extraModules ? [ ],
          userName ? "osmarg",
        }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs userName; profileName = "terminal"; };
          modules = [
            hardware
            ./nixos/terminal.nix
            { networking.hostName = hostName; }
          ]
          ++ extraModules;
        };
    in
    {
      lib = {
        inherit mkGeneralHost mkServerHost mkMinimalHost;
        mkTerminalHost = mkMinimalHost;
      };

      formatter.${system} = pkgs.nixfmt-rfc-style;

      nixosModules = {
        gpu = {
          intel = ./nixos/hardware/gpu/intel.nix;
          radeon = ./nixos/hardware/gpu/radeon.nix;
          nvidia = ./nixos/hardware/gpu/nvidia.nix;
        };

        kernel = {
          zen = ./nixos/hardware/kernel/zen.nix;
          lts = ./nixos/hardware/kernel/lts.nix;
        };
      };

      packages.${system} = {
        inherit
          orgmDot
          orgmWallpaper
          orgmThemes
          codebaseMcp
          ;
        "orgm-dot" = orgmDot;
        "orgm-wallpaper" = orgmWallpaper;
        "orgm-themes" = orgmThemes;
        "codebase-memory-mcp" = codebaseMcp;
        default = orgmDot;
      };

      devShells.${system}.default =
        let
          fhs = import ./nixos/packages/dev-shell.nix pkgsDev;
        in
        pkgsDev.mkShell {
          packages = [ fhs ];
          shellHook = ''
            exec ${fhs}/bin/dev
          '';
        };

      nixosConfigurations = {
        orgm-terminal = mkMinimalHost {
          hostName = "orgm"; hardware = ./nixos/hosts/orgm/hardware-configuration.nix;
          extraModules = [ inputs.impermanence.nixosModules.impermanence ./nixos/impermanence.nix ];
        };
        lenovo-terminal = mkMinimalHost {
          hostName = "lenovo"; hardware = ./nixos/hosts/lenovo/hardware-configuration.nix;
        };
        ero-terminal = mkMinimalHost {
          hostName = "ero"; hardware = ./nixos/hosts/ero/hardware-configuration.nix;
        };
        jarq-terminal = mkMinimalHost {
          hostName = "jarq"; hardware = ./nixos/hosts/jarq/hardware-configuration.nix;
          userName = "jarq";
        };

        cinnamon = mkProfile { profile = ./nixos/profiles/cinnamon.nix; profileName = "cinnamon"; };
        gnome    = mkProfile { profile = ./nixos/profiles/gnome.nix;    profileName = "gnome"; };
        hyprland = mkProfile { profile = ./nixos/profiles/hyprland.nix; profileName = "hyprland"; };
        labwc    = mkProfile { profile = ./nixos/profiles/labwc.nix;    profileName = "labwc"; };
        i3       = mkProfile { profile = ./nixos/profiles/i3.nix;       profileName = "i3"; };
        xfce     = mkProfile { profile = ./nixos/profiles/xfce.nix;     profileName = "xfce"; };
        mate     = mkProfile { profile = ./nixos/profiles/mate.nix;     profileName = "mate"; };
        terminal = mkMinimalHost { hostName = "nixos"; hardware = defaultHardware; };
        server   = mkServerHost  { hostName = "nixos"; hardware = defaultHardware; };

        jarq-xfce = mkHost {
          hostName = "jarq"; hardware = ./nixos/hosts/jarq/hardware-configuration.nix;
          profile = ./nixos/profiles/xfce.nix; profileName = "xfce"; userName = "jarq";
          extraModules = [ ./nixos/hardware/gpu/intel.nix ./nixos/hosts/jarq/default.nix ];
        };
        jarq-mate = mkHost {
          hostName = "jarq"; hardware = ./nixos/hosts/jarq/hardware-configuration.nix;
          profile = ./nixos/profiles/mate.nix; profileName = "mate"; userName = "jarq";
          extraModules = [ ./nixos/hardware/gpu/intel.nix ./nixos/hosts/jarq/default.nix ];
        };
        jarq-i3 = mkHost {
          hostName = "jarq"; hardware = ./nixos/hosts/jarq/hardware-configuration.nix;
          profile = ./nixos/profiles/i3.nix; profileName = "i3"; userName = "jarq";
          extraModules = [ ./nixos/hardware/gpu/intel.nix ./nixos/hosts/jarq/default.nix ];
        };
        jarq-labwc = mkHost {
          hostName = "jarq"; hardware = ./nixos/hosts/jarq/hardware-configuration.nix;
          profile = ./nixos/profiles/labwc.nix; profileName = "labwc"; userName = "jarq";
          extraModules = [ ./nixos/hardware/gpu/intel.nix ./nixos/hosts/jarq/default.nix ];
        };
        jarq-hyprland = mkHost {
          hostName = "jarq"; hardware = ./nixos/hosts/jarq/hardware-configuration.nix;
          profile = ./nixos/profiles/hyprland.nix; profileName = "hyprland"; userName = "jarq";
          extraModules = [ ./nixos/hardware/gpu/intel.nix ./nixos/hosts/jarq/default.nix ];
        };
        jarq-hyprlandqs-caelestia = mkHost {
          hostName = "jarq"; hardware = ./nixos/hosts/jarq/hardware-configuration.nix;
          profile = ./nixos/profiles/hyprlandqs-caelestia.nix; profileName = "hyprlandqs-caelestia"; userName = "jarq";
          extraModules = [ ./nixos/hardware/gpu/intel.nix ./nixos/hosts/jarq/default.nix ];
        };

        orgm-gnome = mkHost {
          hostName = "orgm"; hardware = ./nixos/hosts/orgm/hardware-configuration.nix;
          profile = ./nixos/profiles/gnome.nix; profileName = "gnome";
          extraModules = [ ./nixos/hardware/gpu/nvidia.nix ./nixos/hosts/orgm/ms-7d43.nix ./nixos/gaming/default.nix ./nixos/impermanence.nix ];
        };
        orgm-cinnamon = mkHost {
          hostName = "orgm"; hardware = ./nixos/hosts/orgm/hardware-configuration.nix;
          profile = ./nixos/profiles/cinnamon.nix; profileName = "cinnamon";
          extraModules = [ ./nixos/hardware/gpu/nvidia.nix ./nixos/hosts/orgm/ms-7d43.nix ./nixos/gaming/default.nix ./nixos/impermanence.nix ];
        };
        orgm-hyprland = mkHost {
          hostName = "orgm"; hardware = ./nixos/hosts/orgm/hardware-configuration.nix;
          profile = ./nixos/profiles/hyprland.nix; profileName = "hyprland";
          extraModules = [ ./nixos/hardware/gpu/nvidia.nix ./nixos/hosts/orgm/ms-7d43.nix ./nixos/gaming/default.nix ./nixos/impermanence.nix ];
        };
        orgm-hyprlandqs-caelestia = mkHost {
          hostName = "orgm"; hardware = ./nixos/hosts/orgm/hardware-configuration.nix;
          profile = ./nixos/profiles/hyprlandqs-caelestia.nix; profileName = "hyprlandqs-caelestia";
          extraModules = [ ./nixos/hardware/gpu/nvidia.nix ./nixos/hosts/orgm/ms-7d43.nix ./nixos/gaming/default.nix ./nixos/impermanence.nix ];
        };
        orgm-labwc = mkHost {
          hostName = "orgm"; hardware = ./nixos/hosts/orgm/hardware-configuration.nix;
          profile = ./nixos/profiles/labwc.nix; profileName = "labwc";
          extraModules = [ ./nixos/hardware/gpu/nvidia.nix ./nixos/hosts/orgm/ms-7d43.nix ./nixos/gaming/default.nix ./nixos/impermanence.nix ];
        };
        orgm-i3 = mkHost {
          hostName = "orgm"; hardware = ./nixos/hosts/orgm/hardware-configuration.nix;
          profile = ./nixos/profiles/i3.nix; profileName = "i3";
          extraModules = [ ./nixos/hardware/gpu/nvidia.nix ./nixos/hosts/orgm/ms-7d43.nix ./nixos/gaming/default.nix ./nixos/impermanence.nix ];
        };
        orgm-xfce = mkHost {
          hostName = "orgm"; hardware = ./nixos/hosts/orgm/hardware-configuration.nix;
          profile = ./nixos/profiles/xfce.nix; profileName = "xfce";
          extraModules = [ ./nixos/hardware/gpu/nvidia.nix ./nixos/hosts/orgm/ms-7d43.nix ./nixos/gaming/default.nix ./nixos/impermanence.nix ];
        };
        orgm-mate = mkHost {
          hostName = "orgm"; hardware = ./nixos/hosts/orgm/hardware-configuration.nix;
          profile = ./nixos/profiles/mate.nix; profileName = "mate";
          extraModules = [ ./nixos/hardware/gpu/nvidia.nix ./nixos/hosts/orgm/ms-7d43.nix ./nixos/gaming/default.nix ./nixos/impermanence.nix ];
        };

        ero-labwc = mkHost {
          hostName = "ero"; hardware = ./nixos/hosts/ero/hardware-configuration.nix;
          profile = ./nixos/profiles/labwc.nix; profileName = "labwc";
          extraModules = [ ./nixos/hardware/gpu/intel.nix ];
        };
        ero-i3 = mkHost {
          hostName = "ero"; hardware = ./nixos/hosts/ero/hardware-configuration.nix;
          profile = ./nixos/profiles/i3.nix; profileName = "i3";
          extraModules = [ ./nixos/hardware/gpu/intel.nix ];
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
          hostName = "lenovo"; hardware = ./nixos/hosts/lenovo/hardware-configuration.nix;
          profile = ./nixos/profiles/labwc.nix; profileName = "labwc";
          extraModules = [ ./nixos/hosts/lenovo/p14s-gen2i.nix ./nixos/hosts/lenovo/audio.nix ./nixos/gaming/steam.nix ./nixos/gaming/emulators.nix ./nixos/impermanence.nix ];
        };
        lenovo-gnome = mkHost {
          hostName = "lenovo"; hardware = ./nixos/hosts/lenovo/hardware-configuration.nix;
          profile = ./nixos/profiles/gnome.nix; profileName = "gnome";
          extraModules = [ ./nixos/hosts/lenovo/p14s-gen2i.nix ./nixos/hosts/lenovo/audio.nix ./nixos/gaming/steam.nix ./nixos/gaming/emulators.nix ./nixos/impermanence.nix ];
        };
        lenovo-hyprland = mkHost {
          hostName = "lenovo"; hardware = ./nixos/hosts/lenovo/hardware-configuration.nix;
          profile = ./nixos/profiles/hyprland.nix; profileName = "hyprland";
          extraModules = [ ./nixos/hosts/lenovo/p14s-gen2i.nix ./nixos/hosts/lenovo/audio.nix ./nixos/gaming/steam.nix ./nixos/gaming/emulators.nix ./nixos/impermanence.nix ];
        };
        lenovo-hyprlandqs-caelestia = mkHost {
          hostName = "lenovo"; hardware = ./nixos/hosts/lenovo/hardware-configuration.nix;
          profile = ./nixos/profiles/hyprlandqs-caelestia.nix; profileName = "hyprlandqs-caelestia";
          extraModules = [ ./nixos/hosts/lenovo/p14s-gen2i.nix ./nixos/hosts/lenovo/audio.nix ./nixos/gaming/steam.nix ./nixos/gaming/emulators.nix ./nixos/impermanence.nix ];
        };
        lenovo-i3 = mkHost {
          hostName = "lenovo"; hardware = ./nixos/hosts/lenovo/hardware-configuration.nix;
          profile = ./nixos/profiles/i3.nix; profileName = "i3";
          extraModules = [ ./nixos/hosts/lenovo/p14s-gen2i.nix ./nixos/hosts/lenovo/audio.nix ./nixos/gaming/steam.nix ./nixos/gaming/emulators.nix ./nixos/impermanence.nix ];
        };
        lenovo-xfce = mkHost {
          hostName = "lenovo"; hardware = ./nixos/hosts/lenovo/hardware-configuration.nix;
          profile = ./nixos/profiles/xfce.nix; profileName = "xfce";
          extraModules = [ ./nixos/hosts/lenovo/p14s-gen2i.nix ./nixos/hosts/lenovo/audio.nix ./nixos/gaming/steam.nix ./nixos/gaming/emulators.nix ./nixos/impermanence.nix ];
        };
        lenovo-mate = mkHost {
          hostName = "lenovo"; hardware = ./nixos/hosts/lenovo/hardware-configuration.nix;
          profile = ./nixos/profiles/mate.nix; profileName = "mate";
          extraModules = [ ./nixos/hosts/lenovo/p14s-gen2i.nix ./nixos/hosts/lenovo/audio.nix ./nixos/gaming/steam.nix ./nixos/gaming/emulators.nix ./nixos/impermanence.nix ];
        };
      };
    };
}
