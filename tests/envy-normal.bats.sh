#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
# These evaluated contracts catch wrong GPU ownership, unsafe disk references,
# loss of remote access, and accidental activation of the deferred VM profiles.
nix eval --impure --raw --expr '
  let
    f = builtins.getFlake ("path:" + toString ./.);
    lib = f.inputs.nixpkgs.lib;
    inventory = import ./configurations.nix;
    c = f.nixosConfigurations.envy.config;
    check = message: condition: lib.assertMsg condition message;
    fs = c.fileSystems;
  in
  assert check "envy normal must use Ryoku with a one-second boot menu"
    (c.boot.loader.timeout == 1 && c.programs.ryoku.enable);
  assert check "envy SDDM must enable Num Lock from the greeter"
    (c.services.displayManager.sddm.autoNumlock
      && c.services.displayManager.sddm.settings.General.Numlock == "on");
  assert check "envy must be the only public output for its desktop"
    (inventory.aliases == { }
      && inventory.configurations.envy.profileName == "ryoku"
      && !(f.nixosConfigurations ? envy-normal)
      && !(f.nixosConfigurations ? envy-ryoku));
  assert check "envy must inherit osmarg desktop configuration"
    (c.networking.hostName == "envy" && c.users.users.osmarg.uid == 1000
      && c.home-manager.users.osmarg.home.homeDirectory == "/home/osmarg"
      && builtins.elem "shell" c.orgm.user.programs
      && builtins.elem "nextcloud" c.orgm.user.programs);
  assert check "normal stays default with no host GPU reservation"
    (builtins.attrNames c.specialisation == [ "gaming" "server" "windows-vfio" ]
      && c.environment.etc."orgm/desktop-profile".text == "normal\n"
      && !(c.environment.etc ? "orgm/windows-vm-profile")
      && !(c.systemd.user.services ? lenovo-windows-autostart)
      && !(builtins.any (p: lib.hasPrefix "vfio-pci.ids=" p) c.boot.kernelParams)
      && !(builtins.elem "video=eDP-1:d" c.boot.kernelParams));
  assert check "selected normal-desktop Deskflow integration must not be lost"
    (builtins.any (p: p.appId == "org.deskflow.deskflow") c.services.flatpak.packages);
  assert check "Btrfs subvolumes must share only the authorized SSD filesystem"
    (builtins.all (m: fs.${m}.fsType == "btrfs"
      && fs.${m}.device == "/dev/disk/by-label/ENVY_ROOT")
      [ "/" "/home" "/nix" "/var/log" "/var/lib/windows" ]
      && builtins.elem "subvol=@root" fs."/".options
      && builtins.elem "subvol=@home" fs."/home".options
      && builtins.elem "subvol=@windows" fs."/var/lib/windows".options
      && fs."/boot".device == "/dev/disk/by-label/ENVY_EFI"
      && fs."/boot".fsType == "vfat"
      && c.swapDevices == [ ] && c.zramSwap.enable);
  assert check "Pascal must use NVIDIA580 proprietary offload on the correct bus"
    (!c.hardware.nvidia.open
      && lib.hasPrefix "580." c.hardware.nvidia.package.version
      && c.hardware.nvidia.prime.intelBusId == "PCI:0:2:0"
      && c.hardware.nvidia.prime.nvidiaBusId == "PCI:2:0:0"
      && c.hardware.nvidia.prime.offload.enable
      && c.hardware.nvidia.prime.offload.enableOffloadCmd
      && !c.hardware.nvidia.prime.sync.enable
      && !c.hardware.nvidia.powerManagement.finegrained
      && builtins.elem "i915" c.boot.initrd.kernelModules);
  assert check "remote recovery and hardware baseline must be enabled"
    (c.services.openssh.enable
      && c.services.openssh.settings.PermitRootLogin == "no"
      && !c.services.openssh.settings.PasswordAuthentication
      && c.users.users.osmarg.openssh.authorizedKeys.keys != [ ]
      && c.users.users.osmarg.initialHashedPassword != null
      && c.networking.networkmanager.enable
      && c.hardware.enableRedistributableFirmware
      && c.services.pipewire.enable && c.hardware.bluetooth.enable
      && c.boot.loader.systemd-boot.enable
      && c.boot.loader.systemd-boot.configurationLimit >= 3);
  assert check "NixOS assertions must pass"
    (builtins.all (a: a.assertion) c.assertions);
  "PASS: envy normal configuration, GPU ownership, access and storage\n"
'
