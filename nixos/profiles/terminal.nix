{ pkgs, lib, ... }:

{
  # No display server, no desktop
  services.xserver.enable = false;
  boot.plymouth.enable = false;

  # LTS kernel for stability
  boot.kernelPackages = pkgs.linuxPackages_6_12;
  boot.loader.systemd-boot.editor = false;

  # No GUI apps, no docs
  documentation.enable = false;
  documentation.man.enable = false;
  documentation.nixos.enable = false;
  services.flatpak.enable = lib.mkForce false;

  # Firewall: SSH only
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
  };

  environment.systemPackages = with pkgs; [
    # terminal tools
    tmux zellij
    fzf fd eza bat delta jq trash-cli
    btop fastfetch
    # editors
    helix neovim
    # file manager
    yazi
    # dev
    lazygit
    # storage
    parted gptfdisk e2fsprogs
  ];
}
