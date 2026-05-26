# Edit this configuration file to define what should be installed on
# your system. Help is available in configuration.nix(5) man page
# and in NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, inputs ? null, ... }:

let
  orgmDot = pkgs.callPackage ./packages/orgm-dot.nix { };
in
{
  imports =
    lib.optionals (inputs != null) [ inputs.home-manager.nixosModules.home-manager ]
    ++ lib.optionals (inputs == null) [ <home-manager/nixos> ];

  # Polkit
  


  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = true;
  nix.settings.extra-substituters = [ "https://hyprland.cachix.org" ];
  nix.settings.extra-trusted-public-keys = [ "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=" ];

  programs.nh = {
    enable = true;
    flake = "/home/osmarg/Hobby/dotfiles";
    clean = {
      enable = true;
      dates = "daily";
      extraArgs = "--keep-since 10d --keep 5";
    };
  };

  # Automatic system updates.
  system.autoUpgrade = {
    enable = true;
    dates = "weekly";
    operation = "switch";
    randomizedDelaySec = "45min";
    allowReboot = false;
    flake = "/home/osmarg/Hobby/dotfiles";
    flags = [
      "--update-input"
      "nixpkgs"
      "--update-input"
      "home-manager"
      "-L"
    ];
  };

  # Main kernel for all hosts. Keep host-specific overrides in each host file
  # only when hardware needs a different kernel.
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_zen;

  boot.plymouth.enable = true;
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
  boot.loader.efi.canTouchEfiVariables = true;

  hardware.uinput.enable = true;
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;

  virtualisation.podman = {
    enable = true;
    dockerCompat = true; # alias docker -> podman
    dockerSocket.enable = true;
  };

  boot.kernel.sysctl = {
    "kernel.unprivileged_userns_clone" = 1;
  };

  #virtualisation.docker.enable = true;

  services.flatpak.enable = true;
  systemd.services.flatpak-repo = {
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.flatpak ];
    script = ''
      flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
      flatpak remote-add --if-not-exists gnome-nightly https://nightly.gnome.org/gnome-nightly.flatpakrepo
      flatpak remote-add --if-not-exists flathub-beta https://dl.flathub.org/beta-repo/flathub-beta.flatpakrepo
    '';
  };

  programs.fish.enable = true;
  programs.zoxide.enable = true;
  programs.starship.enable = true;
  programs.git = {
    enable = true;
    config.user.name = "osmar";
    config.user.email = "osmargm1202@gmail.com";
  };

  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "America/Santo_Domingo";

  # Select internationalisation properties.
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

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define user account. Don’t forget to set password with ‘passwd’.
  users.users.osmarg = {
    isNormalUser = true;
    description = "osmarg";
    shell = pkgs.fish;
    subUidRanges = [{ startUid = 100000; count = 65536; }];
    subGidRanges = [{ startGid = 100000; count = 65536; }];
    extraGroups = [ "networkmanager" "wheel" "docker" "osmarg" "podman" "input" "video" "render" ];
    packages = with pkgs; [
      # thunderbird
    ];
  };

  # programs.firefox.enable = true;

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    wget
    curl
    rsync
    vim
    tmux
    stow
    gh
    fish
    figlet
    fzf
    nix-search-tv
    nextcloud-client
    gtk3
    libnotify
    git
    distrobox
    age
    fd
    jq
    orgmDot
    eza
    htop
    btop
    ntfs3g
    gcc
    zoxide
    ncdu
    gnumake
    podman-compose
    freerdp
    nerd-fonts.jetbrains-mono
    nerd-fonts.symbols-only
    noto-fonts-color-emoji
    (chromium.override { enableWideVine = true; })
    (pkgs.writeShellApplication {
      name = "ns";
      runtimeInputs = with pkgs; [
        fzf
        nix-search-tv
      ];
      checkPhase = "";
      text = builtins.readFile "${pkgs.nix-search-tv.src}/nixpkgs.sh";
    })
  ];

  programs.dconf.enable = true;
  programs.adb.enable = true;

  fonts.fontconfig.enable = true;
  fonts.packages = with pkgs; [
    jetbrains-mono
    inter
    nerd-fonts.jetbrains-mono
    nerd-fonts.symbols-only
    noto-fonts-color-emoji
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  #networking.firewall = {
  # enable = true;
  # allowedTCPPorts = [ 47984 47989 47990 48010 ];
  # allowedUDPPorts = [ 47998 47999 48000 48010 ];
  #};
  # Or disable firewall altogether.
  # networking.firewall.enable = false;

  system.stateVersion = "25.11"; # Did you read comment?
}
