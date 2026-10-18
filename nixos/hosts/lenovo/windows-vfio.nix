{
  config,
  lib,
  pkgs,
  userName,
  ...
}:
let
  lookingGlassIddClient = pkgs.callPackage ../../containers/windows/looking-glass-idd-client.nix { };
  virtioInputIso =
    pkgs.runCommand "virtio-input.iso"
      {
        nativeBuildInputs = [ pkgs.xorriso ];
      }
      ''
        mkdir -p "$out"
        xorriso -as mkisofs -V virtio-win -o "$out/virtio-input.iso" -graft-points \
          vioinput/w11/amd64=${pkgs.virtio-win}/vioinput/w11/amd64
      '';

in
{
  orgm.lenovo.windowsVfio.enable = true;

  boot.extraModulePackages = [ config.boot.kernelPackages.kvmfr ];
  boot.kernelModules = [ "kvmfr" ];
  boot.extraModprobeConfig = "options kvmfr static_size_mb=128";

  environment.systemPackages = [ lookingGlassIddClient ];

  home-manager.users.${userName} = {
    home.file = {
      "Apps/windows/compose.yml".source = ../../containers/windows/compose.yml;
      "Apps/windows/compose.lenovo-vfio.yml".text =
        builtins.readFile ../../containers/windows/hosts/lenovo-windows/compose.yml;
      "Apps/windows/virtio-input.iso".source = "${virtioInputIso}/virtio-input.iso";
    };
  };

  boot.kernelParams = lib.mkAfter [
    "intel_iommu=on"
    "iommu=pt"
    "vfio-pci.ids=10de:1fbb"
  ];
  boot.initrd.kernelModules = [
    "vfio"
    "vfio_pci"
    "vfio_iommu_type1"
  ];

  # Rootless Podman runs as the selected user, who belongs to the podman group.
  # Permit it to pass the IOMMU group and Looking Glass shared memory to QEMU.
  services.udev.extraRules = ''
    SUBSYSTEM=="vfio", KERNEL=="[0-9]*", GROUP="podman", MODE="0660"
    KERNEL=="kvmfr0", GROUP="podman", MODE="0660"
  '';

  # A lingering user manager starts outside PAM: allow the supervisor to inherit
  # the same hard memlock limit as a fresh interactive login.
  systemd.services."user@${toString config.users.users.${userName}.uid}" = {
    overrideStrategy = "asDropin";
    serviceConfig.LimitMEMLOCK = "infinity";
  };

  # QEMU must lock guest RAM before the IOMMU can map it for the T500.
  # This takes effect for new login sessions and keeps rootless Podman viable.
  security.pam.loginLimits = [
    {
      domain = userName;
      type = "-";
      item = "memlock";
      value = "unlimited";
    }
  ];

  # The Rofi launcher inherits this from the graphical systemd user session,
  # so rootless Podman can lock guest RAM without a terminal-side prlimit.
  systemd.user.extraConfig = ''
    DefaultLimitMEMLOCK=infinity
  '';

  boot.blacklistedKernelModules = [
    "nouveau"
    "nvidia"
    "nvidia_drm"
    "nvidia_modeset"
    "nvidia_uvm"
  ];

  environment.etc."orgm/windows-vm-profile".text = "lenovo-vfio\n";
}
