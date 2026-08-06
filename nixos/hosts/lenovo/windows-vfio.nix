{ lib, ... }:
{
  orgm.lenovo.windowsVfio.enable = true;

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

  # Rootless Podman runs as user osmarg, who belongs to the podman group.
  # Permit that group to pass the IOMMU group through to QEMU.
  services.udev.extraRules = ''
    SUBSYSTEM=="vfio", KERNEL=="[0-9]*", GROUP="podman", MODE="0660"
  '';

  # QEMU must lock guest RAM before the IOMMU can map it for the T500.
  # This takes effect for new login sessions and keeps rootless Podman viable.
  security.pam.loginLimits = [
    {
      domain = "osmarg";
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

  # Hyprland is launched by the tty1 login shell; give that login process the
  # same hard limit so Rofi inherits it as well.
  systemd.services."getty@tty1".serviceConfig.LimitMEMLOCK = "infinity";
  boot.blacklistedKernelModules = [
    "nouveau"
    "nvidia"
    "nvidia_drm"
    "nvidia_modeset"
    "nvidia_uvm"
  ];

  environment.etc."orgm/windows-vm-profile".text = "lenovo-vfio\n";
}
