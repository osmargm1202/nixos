{ lib, pkgs, role, userName, hostName, ... }:
let
  # Filter the original selection, never the recursively merged config.
  original = import ../../users/osmarg.nix {
    inherit lib role userName hostName;
  };
in
{
  imports = [
    ./server.nix
    ../../hardware/gpu/intel.nix
    ../../gaming/steam.nix
    ../../gaming/emulators.nix
    ../../apps/deskflow.nix
  ];

  orgm.user.programs = lib.mkForce (builtins.filter (p: p != "nextcloud") original.orgm.user.programs);
  orgm.user.autostart = lib.mkForce (builtins.filter (p: !(lib.hasPrefix "nextcloud" p)) original.orgm.user.autostart);

  # Raptor Lake / Iris Xe: use the stable stock kernel, not the shared Zen pin.
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages;
  boot.initrd.kernelModules = [ "i915" ];
  hardware.firmware = [ pkgs.sof-firmware ];
  services.thermald.enable = true;
  boot.loader.timeout = lib.mkForce 1;
  zramSwap.enable = true;

  # Generated hardware owns devices/subvolumes; policy is host-local.
  fileSystems = lib.genAttrs [ "/" "/home" "/nix" "/var/log" "/.snapshots" ] (_: {
    options = [ "compress=zstd" "noatime" ];
  });

  services.gnome.gnome-online-accounts.enable = true;
  xdg.mime.defaultApplications."inode/directory" = lib.mkOverride 40 [ "org.gnome.Nautilus.desktop" ];

  programs.steam = {
    gamescopeSession.enable = lib.mkForce false;
    remotePlay.openFirewall = lib.mkForce false;
    dedicatedServer.openFirewall = lib.mkForce false;
  };
  orgm.gaming.gamescopeTty1.enable = false;

  # This laptop has no external RGB keyboard; retain the user's catalog.
  services.hardware.openrgb.enable = lib.mkForce false;
  home-manager.users.${userName}.systemd.user.services.openrgb-notify = lib.mkForce {};

  # Provision/change account credentials privately, outside declarative state.
  users.mutableUsers = true;
  services.openssh.settings.PermitRootLogin = lib.mkForce "no";
}
