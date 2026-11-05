#!/usr/bin/env python3
"""Evaluate normal and headless X13 boot configurations; never contact the host."""
import json
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[1]
projection = r'''s: let
  c = s.config;
  r = c.specialisation.server.configuration;
  lib = s.pkgs.lib;
  view = x: {
    drv = x.system.build.toplevel.drvPath;
    failedAssertions = map (a: a.message) (builtins.filter (a: !a.assertion) x.assertions);
    sortKey = x.boot.loader.systemd-boot.sortKey;
    marker = x.environment.etc."orgm/desktop-profile".text;
    target = x.systemd.defaultUnit;
    timeout = x.boot.loader.timeout;
    mounts = builtins.mapAttrs (_: fs: { inherit (fs) device fsType options; }) x.fileSystems;
    fstab = x.environment.etc.fstab.text;
    luks = builtins.mapAttrs (_: d: {
      inherit (d) device keyFile tryEmptyPassphrase;
    }) x.boot.initrd.luks.devices;
    graphical = {
      gnome = x.services.desktopManager.gnome.enable;
      goa = x.services.gnome.gnome-online-accounts.enable;
      sddm = x.services.displayManager.sddm.enable;
      autoLogin = x.services.displayManager.autoLogin.enable;
      xserver = x.services.xserver.enable;
      lightdm = x.services.xserver.displayManager.lightdm.enable;
      startx = x.services.xserver.displayManager.startx.enable;
      displayManager = x.systemd.services.display-manager.enable or false;
      xwayland = x.programs.xwayland.enable;
      steam = x.programs.steam.enable;
      gamemode = x.programs.gamemode.enable;
      gamescope = x.programs.steam.gamescopeSession.enable;
      gamescopeTty = x.orgm.gaming.gamescopeTty1.enable;
    };
    flatpak = x.services.flatpak.enable;
    flatpakPackages = map (p: if builtins.isString p then p else p.appId) x.services.flatpak.packages;
    installers = map (n: x.systemd.services.${n}.enable or false)
      [ "flatpak-managed-install" "orgm-artcraft-integrations" ];
    ssh = {
      inherit (x.services.openssh) enable openFirewall ports;
      inherit (x.services.openssh.settings) PermitRootLogin PasswordAuthentication;
    };
    nm = x.networking.networkmanager.enable;
    user = {
      inherit (x.users.users.osmarg) uid isNormalUser extraGroups;
      sudo = x.security.sudo.enable;
      wheelNeedsPassword = x.security.sudo.wheelNeedsPassword;
    };
    credentialsUnset = builtins.all (u:
      u.initialPassword == null && u.initialHashedPassword == null &&
      u.hashedPassword == null && u.password == null && u.hashedPasswordFile == null
    ) [ x.users.users.osmarg x.users.users.root ];
    programs = x.orgm.user.programs;
    autostart = x.orgm.user.autostart;
    userCatalog = x.orgm.user.flatpakPackages;
    containers = builtins.attrNames x.virtualisation.oci-containers.containers;
    vfio = lib.attrByPath [ "orgm" "lenovo" "windowsVfio" "enable" ] false x;
    packages = map (p: p.pname or (lib.getName p)) x.environment.systemPackages;
  };
  original = import ./nixos/users/osmarg.nix {
    inherit lib; role = "desktop"; userName = "osmarg"; hostName = "x13";
  };
in {
  modes = builtins.attrNames c.specialisation;
  normal = view c;
  server = view r;
  expectedPrograms = builtins.filter (p: p != "nextcloud") original.orgm.user.programs;
  expectedAutostart = builtins.filter (p: !(lib.hasPrefix "nextcloud" p)) original.orgm.user.autostart;
  expectedCatalog = original.orgm.user.flatpakPackages;
}'''
result = subprocess.run([
    "nix", "eval", "--impure", "--json", f"path:{root}#nixosConfigurations.x13",
    "--apply", projection,
], cwd=root, text=True, capture_output=True)
assert result.returncode == 0, result.stderr
config = json.loads(result.stdout)
normal, server = config["normal"], config["server"]
assert config["modes"] == ["server"]
assert normal["sortKey"] == "nixos-00-normal"
assert server["sortKey"] == "nixos-01-server"
assert normal["marker"] == "normal\n"
assert server["marker"] == "server\n"
assert normal["target"] == "graphical.target"
assert server["target"] == "multi-user.target"
assert not any(server["graphical"].values()), server["graphical"]
for name in ("gnome", "goa", "sddm", "xserver", "displayManager", "steam", "gamemode"):
    assert normal["graphical"][name], name
# The inherited GNOME configuration does not enable this standalone option.
assert not normal["graphical"]["xwayland"]
assert not normal["graphical"]["gamescope"]
assert not normal["graphical"]["gamescopeTty"]
assert normal["flatpak"] and all(normal["installers"])
assert not server["flatpak"] and not any(server["installers"])
assert server["flatpakPackages"] == []
assert set(config["expectedCatalog"]) <= set(normal["flatpakPackages"])
assert "ai.storyteller.artcraft-launcher" in normal["flatpakPackages"]
assert {"nautilus", "gnome-text-editor", "loupe", "evince", "gnome-console"} <= set(normal["packages"])
for mode in (normal, server):
    assert mode["failedAssertions"] == []
    assert mode["drv"].startswith("/nix/store/") and mode["drv"].endswith(".drv")
    assert mode["timeout"] == 1
    assert mode["ssh"] == {
        "enable": True, "openFirewall": True, "ports": [22],
        "PermitRootLogin": "no", "PasswordAuthentication": True,
    }
    assert mode["nm"]
    assert mode["user"]["uid"] == 1000 and mode["user"]["isNormalUser"]
    assert "wheel" in mode["user"]["extraGroups"] and mode["user"]["sudo"]
    assert mode["user"]["wheelNeedsPassword"]
    assert mode["credentialsUnset"]
    assert mode["programs"] == config["expectedPrograms"]
    assert mode["autostart"] == config["expectedAutostart"]
    assert mode["userCatalog"] == config["expectedCatalog"]
    assert not mode["containers"] and not mode["vfio"]
    assert mode["luks"] == {"cryptroot": {
        "device": "/dev/disk/by-uuid/dde6b70b-af6f-4eba-8cd0-8825ddcb5968",
        "keyFile": None, "tryEmptyPassphrase": False,
    }}
    for mount, subvol in {"/": "@", "/home": "@home", "/nix": "@nix", "/var/log": "@log", "/.snapshots": "@snapshots"}.items():
        fs = mode["mounts"][mount]
        assert (fs["fsType"], fs["device"]) == ("btrfs", "/dev/mapper/cryptroot")
        assert {f"subvol={subvol}", "compress=zstd", "noatime"} <= set(fs["options"])
    boot = mode["mounts"]["/boot"]
    assert boot["device"] == "/dev/disk/by-partuuid/5512d8ef-bc51-4ea9-a3f6-cf575351fa72"
    assert boot["fsType"] == "vfat"
    boot_lines = [line.split() for line in mode["fstab"].splitlines()
                  if line and not line.startswith("#") and len(line.split()) >= 4
                  and line.split()[1] == "/boot"]
    assert len(boot_lines) == 1
    assert boot_lines[0][:3] == [boot["device"], "/boot", "vfat"]
    assert set(boot_lines[0][3].split(",")) == set(boot["options"])
    assert {"fmask=0077", "dmask=0077"} <= set(boot["options"])
assert normal["user"] == server["user"]
assert normal["luks"] == server["luks"]
assert normal["mounts"].keys() == server["mounts"].keys()
for mount in normal["mounts"]:
    if mount != "/boot":
        assert normal["mounts"][mount] == server["mounts"][mount]
normal_boot = set(normal["mounts"]["/boot"]["options"])
server_boot = set(server["mounts"]["/boot"]["options"])
assert "nofail" not in normal_boot
assert not any(o.startswith("x-systemd.device-timeout=") for o in normal_boot)
assert server_boot == normal_boot | {"nofail", "x-systemd.device-timeout=10s"}
print("PASS: x13 normal GNOME and headless server; storage, access policy and complete derivations")
print("Normal drvPath:", normal["drv"])
print("Server drvPath:", server["drv"])
