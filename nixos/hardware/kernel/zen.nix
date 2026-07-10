{ inputs, pkgs, ... }:

{
  boot.kernelPackages = inputs.nixpkgs-zen70.legacyPackages.${pkgs.system}.linuxPackages_zen;
}
