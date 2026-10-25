{
  description = "Modular NixOS flake for orgm";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    # Track current Tailscale releases without moving the system off stable.
    nixpkgs-tailscale.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    # Pinned to the nixos-25.11 rev that shipped zen 7.0.10 -- current
    # nixpkgs' zen (7.1.2) dropped linux/of_gpio.h, breaking the NVIDIA
    # driver build. Only linuxPackages_zen is pulled from this input.
    nixpkgs-zen70.url = "github:NixOS/nixpkgs/25f538306313eae3927264466c70d7001dcea1df";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Keep Ryoku's compositor, plugins and Quickshell on its own locked package set.
    ryoku.url = "github:aethctl/Ryoku-on-NixOS/28c5207586babb136aecf8568ce3ed873fa8f8fd";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-flatpak.url = "github:gmodena/nix-flatpak";
    orgm-multimedia = {
      url = "github:osmargm1202/orgm-multimedia/bd37efee1dd56f1db21a9dd5a7753f8d9664e22d";
      flake = false;
    };
    cinnamon-spices-extensions = {
      url = "github:linuxmint/cinnamon-spices-extensions";
      flake = false;
    };
    dms = {
      url = "github:AvengeMedia/DankMaterialShell/stable";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # qylock = {
    #   # SDDM/quickshell lockscreen themes. Pins its own nixpkgs-unstable
    #   # (quickshell isn't in stable nixpkgs) -- do not add nixpkgs.follows.
    #   url = "github:Darkkal44/qylock";
    # };
    herdr = {
      # tmux replacement (agent multiplexer). Retain upstream's own nixpkgs
      # pin so its Zig toolchain follows the version tested by the project.
      url = "github:ogulcancelik/herdr";
    };
  };

  outputs =
    inputs@{
      flake-parts,
      nixpkgs,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];

      flake =
        let
          # NixOS configurations are host outputs, not perSystem outputs.
          hostSystem = "x86_64-linux";
          # Generic profile outputs use eval-only hardware so pure flake checks do not
          # depend on /etc or any real host. Host-specific outputs pass real hardware.
          defaultHardware = ./nixos/hosts/generic/hardware-configuration.nix;
          configurationInventory = import ./configurations.nix;
          systemBuilders = import ./lib/mk-system.nix {
            inherit
              inputs
              nixpkgs
              defaultHardware
              ;
            system = hostSystem;
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

          nixosModules = {
            orgm = ./nixos/orgm/default.nix;
            multimedia = ./nixos/profiles/multimedia.nix;
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

          nixosConfigurations = builtConfigurations // configurationAliases;
        };

      perSystem =
        {
          pkgs,
          system,
          ...
        }:
        let
          # Separate pkgs instance with allowUnfree for devShells (nix develop does not
          # inherit nixpkgs.config from NixOS modules — needs explicit config here).
          pkgsDev = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          braveOrigin = pkgs.callPackage ./nixos/apps/brave-origin.nix { };
          engram = pkgs.callPackage ./nixos/apps/engram.nix { };
          orgmPackages = import ./nixos/orgm/packages.nix { inherit pkgs; };
          fingerprintPackages = import ./nixos/hardware/fingerprint/synatudor.nix { inherit pkgs; };
        in
        {
          formatter = pkgs.nixfmt-rfc-style;

          packages = orgmPackages // {
            orgm-multimedia = pkgs.callPackage "${inputs.orgm-multimedia}/package.nix" { };
            inherit
              engram
              braveOrigin
              ;
            "brave-origin" = braveOrigin;
            # Build-only outputs; not installed on Envy unless explicitly enabled.
            libfprint-synatudor = fingerprintPackages.libfprint;
            fprintd-synatudor = fingerprintPackages.fprintd;
            envy-fingerprint-test = fingerprintPackages.probe;
            default = braveOrigin;
          };

          checks.multimedia-boot = import ./tests/multimedia-boot.nix {
            inherit pkgs inputs;
          };

          # Dev shell for hacking on this NixOS repo. Enter with `nix develop`.
          devShells.default = pkgsDev.mkShell {
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
        };
    };
}
