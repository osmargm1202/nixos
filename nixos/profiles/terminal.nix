# Terminal-only base system. Same shape as common.nix but no desktop,
# no GUI apps, no flatpak/webapps. Loads only common-dotfiles.nix.
# SSH (key auth) for remote recovery + rebuilds without a live USB.
{
  config,
  pkgs,
  lib,
  inputs ? null,
  userName ? "osmarg",
  ...
}:

let
  hasProgram = program: builtins.elem program config.orgm.user.programs;
  sshAuthorizedKeys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQD3E7OGvfciRdntcDX3SpWlnu5pBw+RycYPIQO4a7h6Zz5WeUc8gB2YbUXZPdQFTVbvjZnAjMqQGhi89GG3K+xlbAZyXl69fL8+75dbicbzygPK3UJi/57zEIANp1u1EF3+w5WBXBXkIKBUbu5IsNAClYr3jX/yQEl1MOZ+o1q1MwAGFS9eJNnyNEroN9cnoFKXmXIS1INKSoPjDL4CE0dWaenQySkNGJY7gRe3w+/YMR4B6vx5G4JfuRBoegF/O0+x7aEPN2RL1MCNzZ6LAM9KwIC72BVyIW1lDsUv6+UzN/S0LGrAV11KcxaEDFtnenX7L5o2i04jd8BAxZLlDvuz4802qIfiHqC8Q/ez9LNIdXLFTPMe04u6HOSxgJVP3Mfh31ZjVmRKUn93oUQwQYmyAq4TvtyNmGQVDOMLboQsU48lMx4k8HObGm4SuUbLNkIOVqnnnax+XhOuylPou9lV77Wtonxj2lgbKufvbnULIdp5+TXPGGPl/+/mLvKCvKoETGFEkQx7hTJg3rwbt/wcpVLyp3lfzKZQt84cD42qQW1bK4/3C4DDZ8XVmSVucM8PEFKPE5uSubF6j1tN/J8CFnhvGGgjRihX8GVhL8UbiVeutTowf/eooQsx2/tymWMF6F3nHXOi4qODR6JI26eMLDBfK0wThHMsFYxJnYaQ== osmarg@orgm"
  ];
  hasSSHKeys = sshAuthorizedKeys != [ ];
in
{
  imports =
    lib.optionals (inputs != null) [
      inputs.home-manager.nixosModules.home-manager
      ../common-dotfiles.nix
    ]
    ++ lib.optionals (inputs == null) [ <home-manager/nixos> ]
    ++ [
      ../apps/lazyvim.nix
      ../dns/hosts.nix
      ../apps/tailscale.nix
      ../functions/clean.nix
    ];
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.${userName} = {
    home.stateVersion = "25.11";
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.settings.auto-optimise-store = true;
  nix.settings.trusted-users = [ "root" userName ];

  # Mismo pin de registry que common.nix: `nix run nixpkgs#app` (aliases
  # Bash de apps efimeras) comparte el store del sistema.
  nix.registry = lib.mkIf (inputs != null) {
    nixpkgs.flake = inputs.nixpkgs;
    herdr.flake = inputs.herdr;
  };

  # nh clean schedule lives in ../functions/clean.nix
  programs.nh = {
    enable = true;
    flake = lib.mkDefault "/home/${userName}/Hobby/nixos";
  };

  # Zen 7.0.10 pinned from nixpkgs-zen70.
  boot.kernelPackages = lib.mkDefault inputs.nixpkgs-zen70.legacyPackages.${pkgs.system}.linuxPackages_zen;

  boot.plymouth = {
    enable = true;
    theme = "bgrt";
  };
  boot.initrd.systemd.enable = true;
  boot.kernelParams = [
    "quiet"
    "splash"
    "loglevel=3"
    "udev.log_level=3"
    "rd.udev.log_level=3"
  ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.consoleMode = "max";
  boot.loader.systemd-boot.editor = false;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.tmp.cleanOnBoot = true;

  virtualisation.podman = lib.mkIf (hasProgram "containers") {
    enable = true;
    dockerCompat = true; # alias docker -> podman
    dockerSocket.enable = true;
  };

  boot.kernel.sysctl = {
    "kernel.unprivileged_userns_clone" = 1;
  };

  programs.bash = lib.mkIf (hasProgram "shell") {
    enable = true;
    completion.enable = true;
    blesh.enable = true;
    loginShellInit = ''
      if [[ $- == *i* && -r "$HOME/.bashrc" ]]; then
        . "$HOME/.bashrc"
      fi
    '';
  };
  programs.git.enable = hasProgram "git";

  hardware.enableRedistributableFirmware = true;
  networking.networkmanager.enable = true;
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };

  # No docs to build (avoids man-cache failures on minimal).
  documentation.enable = false;
  documentation.man.enable = false;
  documentation.nixos.enable = false;

  time.timeZone = "America/Santo_Domingo";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "es_DO.UTF-8";
    LC_IDENTIFICATION = "es_DO.UTF-8";
    LC_MEASUREMENT = "es_DO.UTF-8";
    LC_MONETARY = "es_DO.UTF-8";
    LC_NAME = "es_DO.UTF-8";
    LC_NUMERIC = "es_DO.UTF-8";
    LC_PAPER = "es_DO.UTF-8";
    LC_TELEPHONE = "es_DO.UTF-8";
    LC_TIME = "es_DO.UTF-8";
  };

  # Fixed uid/gid so /home ownership matches the full system.
  users.groups.${userName}.gid = 1000;
  users.users.${userName} = {
    isNormalUser = true;
    uid = 1000;
    description = userName;
    shell = pkgs.bashInteractive;
    group = userName;
    subUidRanges = [ { startUid = 100000; count = 65536; } ];
    subGidRanges = [ { startGid = 100000; count = 65536; } ];
    extraGroups = [
      "networkmanager"
      "wheel"
      "input"
      "video"
      "render"
    ]
    ++ lib.optionals (hasProgram "containers") [
      "docker"
      "podman"
    ];
    openssh.authorizedKeys.keys = sshAuthorizedKeys;
  };

  security.sudo.wheelNeedsPassword = false;

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages =
    lib.optionals (hasProgram "shell") (
      with pkgs;
      [
        wget
        curl
        rsync
        vim
        stow
        age
        ntfs3g
        bashInteractive
        bash-completion
        blesh
        zellij
        fzf
        fd
        ripgrep
        jq
        bat
        delta
        eza
        zoxide
        starship
        trash-cli
        fastfetch
        htop
        parted
        gptfdisk
        e2fsprogs
        (pkgs.writeShellApplication {
          name = "ns";
          runtimeInputs = with pkgs; [
            fzf
            nix-search-tv
          ];
          checkPhase = "";
          text = builtins.readFile "${pkgs.nix-search-tv.src}/nixpkgs.sh";
        })
      ]
    )
    ++ lib.optionals (hasProgram "git") [ pkgs.git ]
    ++ lib.optionals (hasProgram "tmux") [ pkgs.tmux ]
    ++ lib.optionals (hasProgram "development") [
      pkgs.python3
      pkgs.uv
      pkgs.gcc
      pkgs.gnumake
      pkgs.cmake
      pkgs.pkg-config
      pkgs.nodejs_22
      pkgs.typescript
      pkgs.bun
      pkgs.sqlite
    ]
    ++ lib.optionals (hasProgram "personal-development") [
      pkgs.gum
      pkgs.gh
      pkgs.lazygit
      pkgs.helix
    ]
    ++ lib.optionals (hasProgram "syncthing") [ pkgs.syncthing ]
    ++ lib.optionals (hasProgram "containers") [ pkgs.distrobox ];

  # Nerd font glyphs for yazi/starship/fastfetch in the terminal.
  fonts.fontconfig.enable = true;
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    nerd-fonts.roboto-mono
    nerd-fonts.symbols-only
  ];

  services.openssh = {
    enable = true;
    ports = [ 22 ];
    openFirewall = true;
    settings = {
      PasswordAuthentication = !hasSSHKeys;
      KbdInteractiveAuthentication = !hasSSHKeys;
      PermitRootLogin = "no";
      X11Forwarding = false;
    };
  };

  system.stateVersion = "25.11";
}
