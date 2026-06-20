{ pkgs, lib, ... }:

{
  # No display server, no desktop
  services.xserver.enable = false;
  boot.plymouth.enable = lib.mkForce false;

  # LTS kernel for stability (common.nix uses zen via mkDefault)
  boot.kernelPackages = pkgs.linuxPackages_6_12;
  boot.loader.systemd-boot.editor = false;

  # No GUI apps, no docs, no flatpak (common.nix imports flatpak.nix)
  documentation.enable = false;
  documentation.man.enable = false;
  documentation.nixos.enable = false;
  services.flatpak.enable = lib.mkForce false;

  # Firewall: SSH only
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };

  # Only packages NOT already in common.nix
  environment.systemPackages = with pkgs; [
    bat
    delta
    zellij
    helix
    neovim
    yazi
    lazygit
    parted
    gptfdisk
    e2fsprogs
  ];
}
