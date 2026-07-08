{ pkgs, inputs, ... }:

{
  # Driver 580.142 (open and proprietary source trees both) unconditionally
  # includes linux/of_gpio.h, which linux-zen 7.1.2 (common.nix's default
  # kernel, from the current nixpkgs pin) no longer ships. Pull zen from the
  # nixpkgs-zen70 input instead -- same zen flavour, still has the header.
  # Import this module on every host that builds the NVIDIA kernel module.
  boot.kernelPackages =
    (import inputs.nixpkgs-zen70 {
      system = pkgs.stdenv.hostPlatform.system;
      config.allowUnfree = true;
    }).linuxPackages_zen;
}
