{
  config,
  lib,
  pkgs,
  userName,
  ...
}:
let
  lookingGlassIddClient = pkgs.callPackage ../../packages/looking-glass-idd-client.nix { };
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
    xdg.desktopEntries.windows-looking-glass = {
      name = "Windows VM (Looking Glass)";
      comment = "Open the Windows VFIO display without RDP";
      exec = "/home/${userName}/.local/bin/windows-rdp looking-glass";
      icon = "windows";
      terminal = false;
      categories = [
        "System"
        "RemoteAccess"
      ];
      settings = {
        Keywords = "windows;looking glass;vm;vfio;";
        StartupWMClass = "looking-glass-client";
      };
    };

    home.file = {
      "Apps/windows/compose.yml".source = ../../../containers/windows/compose.yml;
      "Apps/windows/compose.lenovo-vfio.yml".source =
        ../../../containers/windows/hosts/lenovo-windows/compose.yml;
      "Apps/windows/Containerfile.spice".source = ../../../containers/windows/Containerfile.spice;
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

  # Rootless Podman runs as user osmarg, who belongs to the podman group.
  # Permit it to pass the IOMMU group and Looking Glass shared memory to QEMU.
  services.udev.extraRules = ''
    SUBSYSTEM=="vfio", KERNEL=="[0-9]*", GROUP="podman", MODE="0660"
    KERNEL=="kvmfr0", GROUP="podman", MODE="0660"
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

  # i3 starts X from the tty1 login shell. Declaring a service override creates
  # the tty1 instance, so explicitly attach it to getty.target as well.
  systemd.services."getty@tty1" = {
    wantedBy = [ "getty.target" ];
    serviceConfig.LimitMEMLOCK = "infinity";
  };
  boot.blacklistedKernelModules = [
    "nouveau"
    "nvidia"
    "nvidia_drm"
    "nvidia_modeset"
    "nvidia_uvm"
  ];

  environment.etc."orgm/windows-vm-profile".text = "lenovo-vfio\n";
}
