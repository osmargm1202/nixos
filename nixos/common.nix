# Edit this configuration file to define what should be installed on
# your system. Help is available in configuration.nix(5) man page
# and in NixOS manual (accessible by running ‘nixos-help’).

{
  config,
  pkgs,
  lib,
  inputs ? null,
  userName ? "osmarg",
  profileName ? null,
  ...
}:

{
  # Boot menu shows "Generation N <label>, built on <date>" -- date is
  # always automatic (build timestamp), this just pins the name part
  # to the profile instead of the default version string.
  system.nixos.label = lib.mkIf (profileName != null) profileName;

  # Logitech G213 RGB (USB HID, no motherboard i2c needed)
  services.hardware.openrgb.enable = true;

  # No generar man pages, info, ni html docs (ahorra ~1+ GiB).
  documentation.enable = false;

  # Firmware requerido por Wi-Fi, Bluetooth, microcode y otros dispositivos.
  hardware.enableRedistributableFirmware = true;

  # Solo los locales que uso.
  i18n.supportedLocales = [ "en_US.UTF-8/UTF-8" "es_DO.UTF-8/UTF-8" ];

  # GC lo maneja nh.clean (semanal, keep 3 + 30d) en clean.nix.
  # nix.gc no se activa para no conflictuar con nh clean.

  imports =
    lib.optionals (inputs != null) [
      inputs.home-manager.nixosModules.home-manager
      inputs.nix-flatpak.nixosModules.nix-flatpak
      ./flatpak.nix
      ./common-dotfiles.nix
      ./webapps.nix
    ]
    ++ lib.optionals (inputs == null) [ <home-manager/nixos> ]
    ++ [
      ./tailscale.nix
      ./clean.nix
    ];

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.${userName} = {
    home.stateVersion = "25.11";
  };

  # Polkit

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.settings.auto-optimise-store = true;

  # Pin `nixpkgs` del registry al input del sistema: `nix run nixpkgs#app`
  # (función fish `,`) comparte el store del sistema en vez de bajar
  # nixpkgs-unstable — sin eval remoto, casi siempre instantáneo.
  nix.registry = lib.mkIf (inputs != null) {
    nixpkgs.flake = inputs.nixpkgs;
    # herdr no esta en nixpkgs; pin para `nix run herdr` (alias fish)
    herdr.flake = inputs.herdr;
  };
  nix.settings.extra-substituters = [ "https://hyprland.cachix.org" ];
  nix.settings.extra-trusted-public-keys = [
    "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
  ];

  # nh clean schedule lives in ./clean.nix
  programs.nh = {
    enable = true;
    flake = lib.mkDefault "/home/${userName}/Hobby/nixos";
  };

  # Weekly auto-upgrade moved to ./autoupdate.nix — import it per host
  # when we decide which machines should self-update.

  # Zen 7.0.10 pinned from nixpkgs-zen70. Host-specific overrides in each
  # host file only when hardware needs a different kernel.
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
  boot.loader.efi.canTouchEfiVariables = true;
  # Default menu timeout was unset (systemd-boot's own ~5s default). Hold a key
  # at the menu to browse generations; normal boot no longer waits for it.
  boot.loader.timeout = 1;

  # NetworkManager-wait-online blocks network-online.target on full WiFi/DHCP
  # association (~5-6s measured), which in turn blocked orgm-dotfiles-repo and
  # home-manager at boot. Nothing here actually needs a guaranteed-online state
  # before login, so stop pulling it into network-online.target.
  systemd.services.NetworkManager-wait-online.wantedBy = lib.mkForce [ ];

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
  services.libinput.enable = true;

  # Define user account. Don’t forget to set password with ‘passwd’.
  # Fixed uid/gid + own primary group so ownership is stable across
  # reinstalls and nixbld can't steal uid 1000 (rootless podman needs this).
  users.groups.${userName}.gid = 1000;
  users.users.${userName} = {
    isNormalUser = true;
    uid = 1000;
    group = userName;
    description = userName;
    shell = pkgs.fish;
    subUidRanges = [
      {
        startUid = 100000;
        count = 65536;
      }
    ];
    subGidRanges = [
      {
        startGid = 100000;
        count = 65536;
      }
    ];
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
      "podman"
      "input"
      "video"
      "render"
    ];
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
    gh
    fzf
    nextcloud-client
    gtk3
    libnotify
    git
    age # dependencia de arranque de fish (load_private_env) — no mover a efimero
    fd
    jq
    trash-cli
    eza
    ntfs3g
    freerdp
    kitty
    # Daily-driver CLI. Project/dev tooling lives in per-project flakes
    # (fish `flakeinit` + nix develop) or ad-hoc `nix shell`.
    # Efimeras via alias fish (nix run): btop fastfetch ncdu
    # yazi sops just xclip figlet tmux nix-search-tv herdr + emuladores.
    # Compose provider: podman 5.x no longer ships built-in `compose`
    # subcommand; `docker compose` shim requires this plugin to exist.
    podman-compose
    bat
    ripgrep
    neovim
    jujutsu
    gum
    steam-run # quick FHS runner for random dynamic executables
    wl-clipboard
    zip
    unzip
    # GUI apps (replaces distrobox versions — NixOS patches loaders automatically)
    vscode
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
    # brave-origin removido del closure (~404 MB); nix file conservado.
  ];

  programs.dconf.enable = true;
  programs.adb.enable = true;

  # Loader shim for dynamic binaries not packaged for NixOS
  # (claude, pi, codex and other custom tools). steam-run (above)
  # covers one-off FHS testing.
  programs.nix-ld.enable = true;

  # FHS shebang shim: third-party scripts (Claude Code plugin hooks, npm
  # postinstalls) hardcode #!/bin/bash, which NixOS doesn't provide by
  # default (only /bin/sh). nix-ld covers ELF binaries; this covers scripts.
  # Also: pi/bash tool hardcodes /usr/sbin/bash.
  systemd.tmpfiles.rules = [
    "L+ /bin/bash - - - - ${pkgs.bash}/bin/bash"
    "L+ /usr/sbin/bash - - - - ${pkgs.bash}/bin/bash"
  ];

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
  programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable OpenSSH daemon. Explicit port (rather than relying on the 22
  # default) so every host stays on the same port even if that default
  # ever changes upstream. openssh's own module auto-opens this port in
  # the firewall (openFirewall defaults to true) — no manual allow needed.
  services.openssh = {
    enable = true;
    ports = [ 22 ];
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = true;
    };
  };

  # 22 (SSH) and sunshine's ports are auto-opened by their own service
  # modules (openssh openFirewall default true; nixos/gaming/sunshine.nix
  # sets services.sunshine.openFirewall = true). Only HTTP/HTTPS need a
  # manual allow here.
  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  system.stateVersion = "25.11"; # Did you read comment?
}
