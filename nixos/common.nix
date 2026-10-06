# Shared desktop base. Personal integrations are selected through
# config.orgm.user.programs; consumers must not infer them from userName.

{
  config,
  pkgs,
  lib,
  inputs ? null,
  userName ? "osmarg",
  profileName ? null,
  ...
}:

let
  zuttyFast = pkgs.writeShellScriptBin "zutty-fast" ''
    exec ${pkgs.zutty}/bin/zutty -font JetBrainsMonoNerdFontMono -fontsize 18 "$@"
  '';
  spf = pkgs.writeShellScriptBin "spf" ''
    exec ${pkgs.superfile}/bin/superfile "$@"
  '';
  hasProgram = program: builtins.elem program config.orgm.user.programs;
  x11TerminalPackages =
    lib.optionals
      (hasProgram "zutty" && builtins.elem profileName [
        "cinnamon"
        "i3"
      ])
      [
        pkgs.zutty
        zuttyFast
      ];
  userPackages =
    lib.optionals (hasProgram "shell") (
      with pkgs;
      [
        wget
        curl
        rsync
        vim
        fzf
        bash-completion
        blesh
        starship
        zoxide
        gtk3
        libnotify
        git-lfs
        zellij
        age
        fd
        jq
        trash-cli
        eza
        ntfs3g
        bat
        ripgrep
        wl-clipboard
        xclip
        zip
        unzip
        unrar
        btop
        spf
        ncdu
        fastfetch
        just
        figlet
        termdown
        nix-search-tv
      ]
    )
    ++ lib.optionals (hasProgram "git") [ pkgs.git ]
    ++ lib.optionals (hasProgram "tmux") [ pkgs.tmux ]
    ++ lib.optionals (hasProgram "kitty") [ pkgs.kitty ]
    ++ lib.optionals (hasProgram "sops") [ pkgs.sops ]
    ++ x11TerminalPackages;
  developmentPackages = with pkgs; [
    python3
    uv
    gcc
    gnumake
    nodejs_22
    bun
    vscode
  ];
  personalDevelopmentPackages = with pkgs; [
    android-tools
    freerdp
    jujutsu
    gum
    gnome-calculator
    gnome-software
    localsend
    gh
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
  desktopUserPackages =
    lib.optionals (hasProgram "nextcloud") [ pkgs.nextcloud-client ]
    ++ lib.optionals (hasProgram "syncthing") [ pkgs.syncthing pkgs.syncthingtray ]
    ++ lib.optionals (hasProgram "development") developmentPackages
    ++ lib.optionals (hasProgram "personal-development") personalDevelopmentPackages
    ++ lib.optionals (hasProgram "steam") [ pkgs.steam-run ]
    ++ lib.optionals (hasProgram "containers") [ pkgs.podman-compose ]
    ++ lib.optionals (!builtins.elem profileName [ "hyprland" "i3" "ryoku" ]) [ pkgs.thunar ];
in
{
  # Boot menu shows "Generation N <label>, built on <date>" -- date is
  # always automatic (build timestamp), this just pins the name part
  # to the profile instead of the default version string.
  system.nixos.label = lib.mkIf (profileName != null) profileName;

  # Every host exposes a stable status-bar profile; specialisations override it.
  environment.etc."orgm/desktop-profile".text = lib.mkDefault "normal\n";

  # Chromium is the browser backend for selected web applications.
  orgm.chromium.enable = hasProgram "webapps";

  # The Logitech RGB daemon is personal hardware integration, not a desktop
  # baseline. It stays off for users that did not select it.
  services.hardware.openrgb.enable = hasProgram "openrgb";

  # No generar man pages, info, ni html docs (ahorra ~1+ GiB).
  documentation.enable = false;

  # Firmware requerido por Wi-Fi, Bluetooth, microcode y otros dispositivos.
  hardware.enableRedistributableFirmware = true;

  # Solo los locales que uso.
  i18n.supportedLocales = [
    "en_US.UTF-8/UTF-8"
    "es_DO.UTF-8/UTF-8"
  ];

  # GC lo maneja nh.clean (semanal, keep 3 + 30d) en functions/clean.nix.
  # nix.gc no se activa para no conflictuar con nh clean.

  imports =
    lib.optionals (inputs != null) [
      inputs.home-manager.nixosModules.home-manager
      inputs.nix-flatpak.nixosModules.nix-flatpak
      inputs.sops-nix.nixosModules.sops
      ./apps/sops.nix
      ./apps/flatpak.nix
      ./common-dotfiles.nix
      ./apps/chromium.nix
      ./apps/firefox/firefox.nix
      ./apps/webapps.nix
      ./apps/rmatrix.nix
    ]
    ++ lib.optionals (inputs == null) [ <home-manager/nixos> ]
    ++ [
      ./apps/lazyvim.nix
      ./dns/hosts.nix
      ./apps/tailscale.nix
      ./functions/clean.nix
      ./apps/udiskie.nix
    ];

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.${userName} = {
    # Compatibility baseline for existing home data, not the Home Manager release.
    home.stateVersion = "25.11";
    # Moving packages into the user profile must preserve the system's no-docs policy.
    programs.man.enable = false;
    home.packages = userPackages ++ desktopUserPackages;
  };

  # Polkit

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.settings.auto-optimise-store = true;

  # Pin `nixpkgs` del registry al input del sistema: `nix run nixpkgs#app`
  # (función Bash `,`) comparte el store del sistema en vez de bajar
  # nixpkgs-unstable — sin eval remoto, casi siempre instantáneo.
  nix.registry = lib.mkIf (inputs != null) {
    nixpkgs.flake = inputs.nixpkgs;
    # herdr no esta en nixpkgs; pin para `nix run herdr` (alias Bash)
    herdr.flake = inputs.herdr;
  };
  nix.settings.extra-substituters = [ "https://hyprland.cachix.org" ];
  nix.settings.extra-trusted-public-keys = [
    "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
  ];

  # nh clean schedule lives in ./functions/clean.nix
  programs.nh = {
    enable = true;
    flake = lib.mkDefault "/home/${userName}/Hobby/nixos";
  };

  # Keep earlyoom idle through five percent available RAM. At four percent it
  # sends SIGTERM to the largest RSS process; SIGKILL remains reserved for two.
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 4;
    freeMemKillThreshold = 2;
    freeSwapThreshold = 100;
    freeSwapKillThreshold = 100;
    extraArgs = [ "--sort-by-rss" ];
    enableNotifications = true;
  };
  # Resolve conflicting EarlyOOM/smartd defaults while preserving desktop notifications.
  services.systembus-notify.enable = true;

  # Weekly auto-upgrade moved to ./functions/autoupdate.nix — import it per host
  # when we decide which machines should self-update.

  # Zen 7.0.10 pinned from nixpkgs-zen70. Host-specific overrides in each
  # host file only when hardware needs a different kernel.
  boot.kernelPackages =
    lib.mkDefault
      inputs.nixpkgs-zen70.legacyPackages.${pkgs.system}.linuxPackages_zen;

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

  # Nothing needed before login depends on network-online.target. Keep its
  # wait service out of boot; dotfile activation uses immutable local sources.
  systemd.services.NetworkManager-wait-online.wantedBy = lib.mkForce [ ];

  hardware.uinput.enable = true;
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;

  virtualisation.podman = lib.mkIf (hasProgram "containers") {
    enable = true;
    dockerCompat = true; # alias docker -> podman
    dockerSocket.enable = true;
  };

  boot.kernel.sysctl = {
    "kernel.unprivileged_userns_clone" = 1;
  };

  #virtualisation.docker.enable = true;

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

  # The NixOS module installs Atuin and initializes it after Blesh, allowing
  # Atuin to use Blesh's history integration without a duplicate package entry.
  programs.atuin = lib.mkIf (hasProgram "shell") {
    enable = true;
    enableBashIntegration = true;
  };
  environment.etc."atuin/config.toml".text = "";
  programs.git.enable = hasProgram "git";

  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  networking.networkmanager.enable = true;
  # KDE Connect needs TCP and UDP 1714-1764 for LAN discovery and pairing.
  programs.kdeconnect.enable = hasProgram "kdeconnect";

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
  # Fixed uid/gid + own primary group so ownership is stable across reinstalls
  # and nixbld can't steal uid 1000.
  users.groups.${userName}.gid = 1000;
  users.users.${userName} = {
    isNormalUser = true;
    uid = 1000;
    group = userName;
    description = userName;
    shell = pkgs.bashInteractive;
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
      "input"
      "video"
      "render"
    ]
    ++ lib.optionals (hasProgram "containers") [
      "docker"
      "podman"
    ];
  };

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = [ ];
  environment.variables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  xdg.mime = {
    enable = true;
    defaultApplications = {
      "inode/directory" = lib.mkForce [
        (if builtins.elem profileName [ "hyprland" "ryoku" ] then "org.gnome.Nautilus.desktop" else "thunar.desktop")
      ];
      "text/plain" = lib.mkDefault [ "org.gnome.TextEditor.desktop" ];
      "text/markdown" = lib.mkDefault [ "org.gnome.TextEditor.desktop" ];
      "text/x-markdown" = lib.mkDefault [ "org.gnome.TextEditor.desktop" ];
      "application/x-zerosize" = lib.mkDefault [
        (if profileName == "cinnamon" then "xed.desktop" else "org.gnome.TextEditor.desktop")
      ];
      "text/x-lua" = lib.mkForce [ "nvim.desktop" ];
      "text/x-python" = lib.mkForce [ "nvim.desktop" ];
      "application/json" = lib.mkForce [ "nvim.desktop" ];
      "application/x-shellscript" = lib.mkForce [ "nvim.desktop" ];
    };
  };

  programs.dconf.enable = true;

  # Third-party AI CLIs use dynamic loaders and hard-coded Bash shebangs.
  programs.nix-ld.enable = hasProgram "ai";
  systemd.tmpfiles.rules = lib.optionals (hasProgram "ai") [
    "L+ /bin/bash - - - - ${pkgs.bash}/bin/bash"
    "L+ /usr/sbin/bash - - - - ${pkgs.bash}/bin/bash"
  ];

  fonts.fontconfig.enable = true;
  fonts.packages = with pkgs; [
    jetbrains-mono
    inter
    noto-fonts
    font-awesome
    nerd-fonts.jetbrains-mono
    nerd-fonts.roboto-mono
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
      PasswordAuthentication = lib.mkDefault true;
    };
  };

  # LocalSend and Deskflow are user-selected LAN integrations.
  networking.firewall = {
    allowedTCPPorts =
      [
        80
        443
      ]
      ++ lib.optionals (hasProgram "development") [ 53317 ]
      ++ lib.optionals (hasProgram "deskflow") [ 24800 ];
    allowedUDPPorts = lib.optionals (hasProgram "development") [ 53317 ];
  };

  # Compatibility baseline for existing system data; the release follows flake.nix.
  system.stateVersion = "25.11";
}
