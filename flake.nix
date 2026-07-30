{
  description = "Modular NixOS flake for orgm";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    # Pinned to the nixos-25.11 rev that shipped zen 7.0.10 -- current
    # nixpkgs' zen (7.1.2) dropped linux/of_gpio.h, breaking the NVIDIA
    # driver build. Only linuxPackages_zen is pulled from this input.
    nixpkgs-zen70.url = "github:NixOS/nixpkgs/25f538306313eae3927264466c70d7001dcea1df";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-flatpak.url = "github:gmodena/nix-flatpak";
    cinnamon-spices-extensions = {
      url = "github:linuxmint/cinnamon-spices-extensions";
      flake = false;
    };
    snappy-switcher.url = "github:OpalAayan/snappy-switcher";
    caelestia-shell = {
      url = "github:osmargm1202/shell";
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
    # qylock = {
    #   # SDDM/quickshell lockscreen themes. Pins its own nixpkgs-unstable
    #   # (quickshell isn't in stable nixpkgs) -- do not add nixpkgs.follows.
    #   url = "github:Darkkal44/qylock";
    # };
    zen-browser-flake = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    herdr = {
      # tmux replacement (agent multiplexer). Own nixpkgs pin -- needs
      # zig_0_15 which may not exist on our stable 25.11 input.
      url = "github:ogulcancelik/herdr";
    };
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
      pkgsDev = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      braveOrigin = pkgs.callPackage ./nixos/packages/brave-origin.nix { };
      engram = pkgs.callPackage ./nixos/packages/engram.nix { };
      rtk = pkgs.callPackage ./nixos/packages/rtk.nix { };
      defaultHardware = ./nixos/hosts/generic/hardware-configuration.nix;
      configurationInventory = import ./configurations.nix;
      systemBuilders = import ./lib/mk-system.nix {
        inherit
          inputs
          nixpkgs
          system
          defaultHardware
          ;
        inherit (configurationInventory) profiles;
      };
      builtConfigurations = nixpkgs.lib.mapAttrs (
        _: systemBuilders.mkSystem
      ) configurationInventory.configurations;
      configurationAliases = nixpkgs.lib.mapAttrs (
        _: target: builtConfigurations.${target}
      ) configurationInventory.aliases;

    in
    {
      lib = systemBuilders;

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
          engram
          rtk
          braveOrigin
          ;
        "brave-origin" = braveOrigin;
        default = braveOrigin;
      };

      # Dev shell for hacking on this NixOS repo. Enter with `nix develop`.
      # The old FHS env (nixos/packages/dev-shell.nix) is kept on disk as
      # reference but no longer wired anywhere.
      devShells.${system}.default = pkgsDev.mkShell {
        packages = with pkgsDev; [
          # Nix tooling
          nixfmt-rfc-style
          nil
          statix # lint anti-patterns
          deadnix # find dead Nix code
          nix-output-monitor # prettier nix build output (nom)
          nvd # diff derivations between generations
          # Git
          git
          lazygit # TUI for git
          # General
          just # command runner
          typos # spell check
        ];
      };

      nixosConfigurations = builtConfigurations // configurationAliases;
    };
}
