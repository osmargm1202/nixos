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
  boot.blacklistedKernelModules = [
    "nouveau"
    "nvidia"
    "nvidia_drm"
    "nvidia_modeset"
    "nvidia_uvm"
  ];

  environment.etc."orgm/windows-vm-profile".text = "lenovo-vfio\n";
}
