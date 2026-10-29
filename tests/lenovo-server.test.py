#!/usr/bin/env python3
"""Check the standalone server's boot, remote access and existing VM contract."""
import json
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[1]
projection = r'''systems: let
  collect = c: {
    host = c.networking.hostName;
    profile = c.environment.etc."orgm/desktop-profile".text;
    vmProfile = c.environment.etc."orgm/windows-vm-profile".text;
    unit = c.systemd.defaultUnit;
    ssh = c.services.openssh.enable;
    tailscale = c.services.tailscale.enable;
    network = c.networking.networkmanager.enable;
    podman = c.virtualisation.podman.enable;
    vfio = c.orgm.lenovo.windowsVfio.enable;
    kernel = c.boot.kernelPackages.kernel.version;
    kernelParams = c.boot.kernelParams;
    initrd = c.boot.initrd.kernelModules;
    user = { inherit (c.users.users.osmarg) uid group linger; };
    vm = let service = c.systemd.user.services.lenovo-windows-autostart; in {
      inherit (service) wantedBy restartIfChanged stopIfChanged serviceConfig;
    };
    xserver = c.services.xserver.enable;
    tcp = c.networking.firewall.allowedTCPPorts;
    udp = c.networking.firewall.allowedUDPPorts;
  };
in {
  old = collect systems.lenovo.config.specialisation.server.configuration;
  new = collect systems.lenovo-server.config;
  label = systems.lenovo-server.config.system.nixos.label;
  specialisations = builtins.attrNames systems.lenovo-server.config.specialisation;
  syncthing = systems.lenovo-server.config.home-manager.users.osmarg.systemd.user.services.syncthing.Service.ExecStart;
  nextcloud = systems.lenovo-server.config.systemd.user.timers.nextcloud-server.wantedBy;
  flake = systems.lenovo-server.config.programs.nh.flake;
}'''
data = json.loads(subprocess.check_output([
    "nix", "eval", "--json", f"path:{root}#nixosConfigurations", "--apply", projection,
], text=True))
old, new = data["old"], data["new"]
for key in ("host", "profile", "vmProfile", "unit", "ssh", "tailscale", "network", "podman", "vfio", "user", "xserver"):
    assert old[key] == new[key], (key, old[key], new[key])
assert set(old["tcp"]) == set(new["tcp"]) and set(old["udp"]) == set(new["udp"])
assert old["kernel"] == new["kernel"]
for required in ("video=eDP-1:d", "intel_iommu=on", "iommu=pt", "vfio-pci.ids=10de:1fbb"):
    assert required in old["kernelParams"] and required in new["kernelParams"], required
assert {"i915", "vfio", "vfio_pci", "vfio_iommu_type1"} <= set(new["initrd"])
for key in ("wantedBy", "restartIfChanged", "stopIfChanged", "serviceConfig"):
    assert old["vm"][key] == new["vm"][key], key
assert data["label"] == "lenovo-server" and not data["specialisations"]
assert "syncthing" in data["syncthing"][0] and "timers.target" in data["nextcloud"]
assert data["flake"] == "/home/osmarg/Hobby/nixos"
print("PASS: standalone Lenovo server preserves SSH, VPN, VFIO, Windows supervisor and synchronization")
