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
  boot.blacklistedKernelModules = [
    "nouveau"
    "nvidia"
    "nvidia_drm"
    "nvidia_modeset"
    "nvidia_uvm"
  ];

  environment.etc."orgm/windows-vm-profile".text = "lenovo-vfio\n";
}
