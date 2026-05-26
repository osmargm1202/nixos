# Generic eval-only hardware module for flake profile outputs.
# Real host configurations must use nixos/hosts/<host>/hardware-configuration.nix.
{ lib, ... }:

{
  imports = [ ];

  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
  };

  boot.loader.grub.enable = false;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
