# Minimal recovery system: SSH only. Use to rebuild the real config from scratch.
{
  config,
  lib,
  pkgs,
  userName ? "osmarg",
  ...
}:

let
  sshAuthorizedKeys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQD3E7OGvfciRdntcDX3SpWlnu5pBw+RycYPIQO4a7h6Zz5WeUc8gB2YbUXZPdQFTVbvjZnAjMqQGhi89GG3K+xlbAZyXl69fL8+75dbicbzygPK3UJi/57zEIANp1u1EF3+w5WBXBXkIKBUbu5IsNAClYr3jX/yQEl1MOZ+o1q1MwAGFS9eJNnyNEroN9cnoFKXmXIS1INKSoPjDL4CE0dWaenQySkNGJY7gRe3w+/YMR4B6vx5G4JfuRBoegF/O0+x7aEPN2RL1MCNzZ6LAM9KwIC72BVyIW1lDsUv6+UzN/S0LGrAV11KcxaEDFtnenX7L5o2i04jd8BAxZLlDvuz4802qIfiHqC8Q/ez9LNIdXLFTPMe04u6HOSxgJVP3Mfh31ZjVmRKUn93oUQwQYmyAq4TvtyNmGQVDOMLboQsU48lMx4k8HObGm4SuUbLNkIOVqnnnax+XhOuylPou9lV77Wtonxj2lgbKufvbnULIdp5+TXPGGPl/+/mLvKCvKoETGFEkQx7hTJg3rwbt/wcpVLyp3lfzKZQt84cD42qQW1bK4/3C4DDZLZ8XVmSVucM8PEFKPE5uSubF6j1tN/J8CFnhvGGgjRihX8GVhL8UbiVeutTowf/eooQsx2/tymWMF6F3nHXOi4qODR6JI26eMLDBfK0wThHMsFYxJnYaQ== osmarg@orgm"
  ];
in
{
  boot.kernelPackages = pkgs.linuxPackages_lts;

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.editor = false;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.tmp.cleanOnBoot = true;

  documentation.enable = false;
  documentation.man.enable = false;
  documentation.nixos.enable = false;

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" userName ];
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  networking = {
    useDHCP = lib.mkDefault true;
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 ];
    };
    nameservers = [ "1.1.1.1" "9.9.9.9" ];
  };

  services.resolved.enable = false;

  time.timeZone = "America/Santo_Domingo";
  i18n.defaultLocale = "en_US.UTF-8";

  users.mutableUsers = true;
  users.users.${userName} = {
    isNormalUser = true;
    shell = pkgs.fish;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = sshAuthorizedKeys;
  };

  programs.fish.enable = true;

  security.sudo.wheelNeedsPassword = false;

  services.openssh = {
    enable = true;
    ports = [ 22 ];
    openFirewall = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  environment.systemPackages = with pkgs; [
    git
    vim
    curl
    wget
    htop
    ripgrep
    fish
    distrobox
    gh
    ncdu
    podman
    rsync
    parted
    gptfdisk
    e2fsprogs
  ];

  system.stateVersion = "25.11";
}
