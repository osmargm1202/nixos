{
  config,
  lib,
  pkgs,
  ...
}:

let
  sshPort = 22;
  sshAuthorizedKeys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQD3E7OGvfciRdntcDX3SpWlnu5pBw+RycYPIQO4a7h6Zz5WeUc8gB2YbUXZPdQFTVbvjZnAjMqQGhi89GG3K+xlbAZyXl69fL8+75dbicbzygPK3UJi/57zEIANp1u1EF3+w5WBXBXkIKBUbu5IsNAClYr3jX/yQEl1MOZ+o1q1MwAGFS9eJNnyNEroN9cnoFKXmXIS1INKSoPjDL4CE0dWaenQySkNGJY7gRe3w+/YMR4B6vx5G4JfuRBoegF/O0+x7aEPN2RL1MCNzZ6LAM9KwIC72BVyIW1lDsUv6+UzN/S0LGrAV11KcxaEDFtnenX7L5o2i04jd8BAxZLlDvuz4802qIfiHqC8Q/ez9LNIdXLFTPMe04u6HOSxgJVP3Mfh31ZjVmRKUn93oUQwQYmyAq4TvtyNmGQVDOMLboQsU48lMx4k8HObGm4SuUbLNkIOVqnnnax+XhOuylPou9lV77Wtonxj2lgbKufvbnULIdp5+TXPGGPl/+/mLvKCvKoETGFEkQx7hTJg3rwbt/wcpVLyp3lfzKZQt84cD42qQW1bK4/3C4DDZLZ8XVmSVucM8PEFKPE5uSubF6j1tN/J8CFnhvGGgjRihX8GVhL8UbiVeutTowf/eooQsx2/tymWMF6F3nHXOi4qODR6JI26eMLDBfK0wThHMsFYxJnYaQ== osmarg@orgm"
  ];
  hasSSHKeys = sshAuthorizedKeys != [ ];

  allowPiholeDNS = true;
  allowedTCPPorts = [
    sshPort
    80
    443
  ]
  ++ lib.optionals allowPiholeDNS [ 53 ];
  allowedUDPPorts = lib.optionals allowPiholeDNS [ 53 ];

  fail2ban = {
    enable = true;
    maxretry = 5;
    bantime = "1h";
    findtime = "10m";
  };

  autoUpgrade = {
    enable = false;
    flake = "/home/osmarg/Hobby/nixos#ero-server";
    dates = "Sun 04:00";
    randomizedDelaySec = "45min";
    allowReboot = false;
  };

  dockerPrune = {
    enable = false;
    dates = "weekly";
    flags = [ "--all" ];
  };

  resticBackup = {
    enable = false;
    repositoryFile = "/run/secrets/restic-repository";
    passwordFile = "/run/secrets/restic-password";
    paths = [
      "/home/osmarg"
      "/var/lib/docker/volumes"
    ];
    exclude = [
      "/home/osmarg/.cache"
      "/home/osmarg/**/node_modules"
      "/home/osmarg/**/.venv"
      "/var/lib/docker/overlay2"
      "/var/lib/docker/tmp"
    ];
  };
in
{
  boot.kernelPackages = pkgs.linuxPackages;
  boot.tmp.cleanOnBoot = true;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = [
      "root"
      "osmarg"
    ];
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
  nix.optimise.automatic = true;

  networking = {
    networkmanager.enable = true; # nmtui / nmcli for network config
    firewall = {
      enable = true;
      inherit allowedTCPPorts allowedUDPPorts;
      checkReversePath = "loose";
    };
    nameservers = [
      "1.1.1.1"
      "9.9.9.9"
    ];
  };

  services.resolved.enable = false;

  time.timeZone = "America/Santo_Domingo";
  i18n.defaultLocale = "en_US.UTF-8";

  users.mutableUsers = true;
  users.users.osmarg = {
    isNormalUser = true;
    description = "osmar";
    shell = pkgs.fish;
    extraGroups = [
      "wheel"
      "docker"
      "systemd-journal"
      "networkmanager"
    ];
    openssh.authorizedKeys.keys = sshAuthorizedKeys;
  };

  programs.fish.enable = true;
  programs.git.enable = true;

  security.sudo.wheelNeedsPassword = true;

  services.openssh = {
    enable = true;
    ports = [ sshPort ];
    openFirewall = false;
    settings = {
      PasswordAuthentication = !hasSSHKeys;
      KbdInteractiveAuthentication = !hasSSHKeys;
      PermitRootLogin = "no";
      X11Forwarding = false;
    };
  };

  services.fail2ban = {
    inherit (fail2ban) enable maxretry bantime;
    bantime-increment.enable = true;
    jails.sshd.settings = {
      enabled = true;
      port = toString sshPort;
      filter = "sshd";
      backend = "systemd";
      maxretry = fail2ban.maxretry;
      findtime = fail2ban.findtime;
      bantime = fail2ban.bantime;
    };
  };

  virtualisation.docker = {
    enable = true;
    autoPrune = {
      inherit (dockerPrune) enable dates flags;
    };
    daemon.settings = {
      "live-restore" = true;
      "log-driver" = "json-file";
      "log-opts" = {
        "max-size" = "50m";
        "max-file" = "5";
      };
    };
  };

  services.restic.backups.server = lib.mkIf resticBackup.enable {
    inherit (resticBackup)
      repositoryFile
      passwordFile
      paths
      exclude
      ;
    initialize = true;
    timerConfig = {
      OnCalendar = "daily";
      RandomizedDelaySec = "2h";
      Persistent = true;
    };
    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 6"
    ];
  };

  system.autoUpgrade = {
    inherit (autoUpgrade)
      enable
      flake
      dates
      randomizedDelaySec
      allowReboot
      ;
    operation = "switch";
  };

  environment.systemPackages =
    with pkgs;
    [
      age
      bat
      dnsutils
      btop
      ctop
      curl
      dive
      docker-buildx
      docker-compose
      dust
      duf
      eza
      fd
      fish
      fzf
      git
      htop
      iftop
      inetutils
      iotop
      jq
      lazydocker
      lsof
      mosh
      mtr
      nano
      ncdu
      nethogs
      nmap
      openssl
      pciutils
      restic
      ripgrep
      rsync
      smartmontools
      tcpdump
      tmux
      tree
      unzip
      usbutils
      vim
      wget
      yq-go
      zoxide
    ]
    ++ lib.optionals (pkgs ? dtop) [ pkgs.dtop ];

  services.fstrim.enable = true;
  services.smartd.enable = true;

  system.stateVersion = "25.11";
}
