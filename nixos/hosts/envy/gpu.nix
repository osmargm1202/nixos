{ config, lib, ... }:
let vfio = config.orgm.envy.windowsVfio.enable;
in {
  hardware.nvidia-container-toolkit.enable = !vfio;
  assertions = [{
    assertion = vfio == builtins.elem config.orgm.envy.mode [ "windows" "server" ];
    message = "Envy GPU ownership must match the boot mode; reboot instead of live rebinding.";
  }];
  services.xserver.videoDrivers = if vfio then [ "modesetting" ] else [ "nvidia" ];
  hardware.nvidia = lib.mkMerge [ {
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
    open = false;
  } (lib.mkIf (!vfio) {
    modesetting.enable = true;
    nvidiaSettings = true;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    prime = {
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:2:0:0";
      offload.enable = true;
      offload.enableOffloadCmd = true;
    };
  }) ];
  boot.kernelParams = lib.optionals vfio [ "intel_iommu=on" "iommu=pt" "vfio-pci.ids=10de:1d13" ];
  boot.initrd.kernelModules = lib.mkIf vfio (lib.mkBefore [ "vfio" "vfio_pci" "vfio_iommu_type1" ]);
  boot.blacklistedKernelModules = lib.optionals vfio [ "nouveau" "nvidia" "nvidia_drm" "nvidia_modeset" "nvidia_uvm" ];
  services.udev.extraRules = lib.mkIf vfio ''
    SUBSYSTEM=="vfio", KERNEL=="[0-9]*", GROUP="kvm", MODE="0660"
  '';
  security.pam.loginLimits = lib.mkIf vfio [{ domain = "osmarg"; type = "-"; item = "memlock"; value = "unlimited"; }];
  # The lingering user manager starts outside a PAM login; its inherited hard
  # limit must permit VFIO, not merely the limits of interactive shells.
  systemd.services."user@1000" = lib.mkIf vfio {
    overrideStrategy = "asDropin";
    serviceConfig.LimitMEMLOCK = "infinity";
  };
  systemd.user.extraConfig = lib.mkIf vfio "DefaultLimitMEMLOCK=infinity";
}
