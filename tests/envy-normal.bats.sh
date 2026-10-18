#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
# These evaluated contracts catch wrong GPU ownership, unsafe disk references,
# loss of remote access, and accidental activation of the deferred VM profiles.
nix eval --impure --raw --expr '
  let
    f = builtins.getFlake ("path:" + toString ./.);
    lib = f.inputs.nixpkgs.lib;
    pkgs = f.nixosConfigurations.envy.pkgs;
    inventory = import ./configurations.nix;
    c = f.nixosConfigurations.envy.config;
    check = message: condition: lib.assertMsg condition message;
    fs = c.fileSystems;
    stock = name: let packages = builtins.filter (p: lib.getName p == name) c.environment.systemPackages;
      in packages != [] && builtins.all (p: toString p == toString pkgs.${name}) packages;
  in
  assert check "envy must use Sway as its desktop"
    (c.boot.loader.timeout == 1 && c.programs.sway.enable
      && !c.programs.hyprland.enable && !(c.programs.ryoku.enable or false)
      && !c.programs.niri.enable && c.services.displayManager.defaultSession == "sway");
  assert check "envy SDDM must enable Num Lock from the greeter"
    (c.services.displayManager.sddm.autoNumlock
      && c.services.displayManager.sddm.settings.General.Numlock == "on");
  assert check "envy must be the only public output for its desktop"
    (inventory.aliases == { }
      && inventory.configurations.envy.profileName == "sway"
      && !(f.nixosConfigurations ? envy-normal)
      && !(f.nixosConfigurations ? envy-ryoku)
      && !(f.nixosConfigurations ? envy-hyprland)
      && !(f.nixosConfigurations ? envy-sway));
  assert check "Envy must load its Sway session services and editable dotfiles"
    (c.systemd.user.services ? orgm-sway-waybar
      && c.systemd.user.services ? orgm-sway-dock
      && !(c.systemd.user.services ? ryoku-shell)
      && !(c.systemd.user.services ? ryoku-materialize)
      && (builtins.fromJSON c.environment.etc."orgm-dot/context.json".text).profile == "sway");
  assert check "Sway must use SwayFX and its wlroots portal"
    (c.programs.sway.package.pname == "swayfx"
      && c.xdg.portal.wlr.enable
      && builtins.all stock [ "waybar" "swayidle" ]
      && builtins.any (p: lib.getName p == "orgm-qylock") c.environment.systemPackages
      && !(builtins.any (p: builtins.elem (lib.getName p) [ "swaylock" "swaylock-effects" ]) c.environment.systemPackages)
      && !(c.environment.etc ? "scrolloverview.so")
      && !(c.environment.etc ? "hyprglass.so")
      && !(c.environment.etc ? "HyprWindowShade.so"));
  assert check "Envy must preserve selected apps and tray cleanup"
    (!(builtins.any (p: builtins.elem (lib.getName p) [ "syncthingtray" "syncthingtray-minimal" "nextcloud-client" ]) c.environment.systemPackages)
      && builtins.elem "syncthing" c.orgm.user.programs
      && lib.hasInfix "syncthing serve --no-browser --no-restart"
        (builtins.toString c.home-manager.users.osmarg.systemd.user.services.syncthing.Service.ExecStart)
      && !(c.home-manager.users.osmarg.home.file ? ".local/bin/hypr-tray-applets")
      && (builtins.fromJSON c.environment.etc."orgm-dot/context.json".text).profile == "sway"
      && !(builtins.any (cmd: lib.hasInfix "tailscale systray" cmd || lib.hasInfix "syncthingtray" cmd) c.orgm.user.autostart));
  assert check "envy must inherit osmarg desktop configuration"
    (c.networking.hostName == "envy" && c.users.users.osmarg.uid == 1000
      && c.home-manager.users.osmarg.home.homeDirectory == "/home/osmarg"
      && builtins.elem "shell" c.orgm.user.programs
      && !(builtins.elem "nextcloud" c.orgm.user.programs)
      && c.services.gnome.gnome-online-accounts.enable);
  assert check "normal stays default with no host GPU reservation"
    (builtins.attrNames c.specialisation == [ "gaming" "server" "windows-vfio" ]
      && c.environment.etc."orgm/desktop-profile".text == "normal\n"
      && c.environment.etc."orgm/windows-vm-profile".text == "envy-render-node\n"
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
