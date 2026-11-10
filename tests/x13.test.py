#!/usr/bin/env python3
"""Evaluate the X13 host contract without building or contacting the laptop."""
import hashlib
import json
from pathlib import Path
import re
import subprocess

root = Path(__file__).resolve().parents[1]
hardware = root / "nixos/hosts/x13/hardware-configuration.nix"
before = hardware.read_bytes()
projection = r'''s: let
  c = s.config;
  lib = s.pkgs.lib;
  hm = c.home-manager.users.osmarg;
  original = import ./nixos/users/osmarg.nix {
    inherit lib; role = "desktop"; userName = "osmarg"; hostName = "x13";
  };
  base = import ./nixos/profiles/gnome.nix { pkgs = s.pkgs; };
  extensions = ps: map (p: p.extensionUuid) (builtins.filter (p: p ? extensionUuid) ps);
  names = ps: map (p: p.pname or (lib.getName p)) ps;
in {
  host = c.networking.hostName;
  context = builtins.fromJSON c.environment.etc."orgm-dot/context.json".text;
  programs = c.orgm.user.programs;
  expectedPrograms = builtins.filter (p: p != "nextcloud") original.orgm.user.programs;
  autostart = c.orgm.user.autostart;
  expectedAutostart = builtins.filter (p: !(lib.hasPrefix "nextcloud" p)) original.orgm.user.autostart;
  flatpaks = map (p: if builtins.isString p then p else p.appId) c.services.flatpak.packages;
  expectedFlatpaks = original.orgm.user.flatpakPackages;
  artcraft = builtins.filter (p: builtins.isAttrs p && p.appId == "ai.storyteller.artcraft-launcher") c.services.flatpak.packages;
  artcraftIntegrations = builtins.hasAttr "orgm-artcraft-integrations" c.systemd.services;
  failedAssertions = map (a: a.message) (builtins.filter (a: !a.assertion) c.assertions);
  systemdInitrd = c.boot.initrd.systemd.enable;
  noEmbeddedLuksKey = c.boot.initrd.luks.devices.cryptroot.keyFile == null && !c.boot.initrd.luks.devices.cryptroot.tryEmptyPassphrase;
  accountRecovery = c.users.users.osmarg.isNormalUser && builtins.elem "wheel" c.users.users.osmarg.extraGroups && c.security.sudo.enable;
  packages = names c.environment.systemPackages;
  hmPackages = names hm.home.packages;
  systemExtensions = extensions c.environment.systemPackages;
  userExtensions = extensions hm.home.packages;
  expectedExtensions = builtins.filter (uuid: uuid != "gnome-ui-tune@itstime.tech") (extensions base.environment.systemPackages);
  webapps = c.orgm.user.webapps;
  expectedWebapps = original.orgm.user.webapps ++ [ "slc-daily" "slc-vill-docs" "orgm-adm" "orgm-automation" "orgm-code" ];
  enabledExtensions = hm.dconf.settings."org/gnome/shell".enabled-extensions or [];
  gdm = c.services.displayManager.gdm.enable;
  sddm = c.services.displayManager.sddm.enable;
  lockDisabled = hm.dconf.settings."org/gnome/desktop/lockdown".disable-lock-screen;
  lockEnabled = hm.dconf.settings."org/gnome/desktop/screensaver".lock-enabled;
  lockBinding = hm.dconf.settings."org/gnome/settings-daemon/plugins/media-keys".screensaver;
  gnome = c.services.desktopManager.gnome.enable;
  session = c.services.displayManager.defaultSession;
  goa = c.services.gnome.gnome-online-accounts.enable;
  browser = c.orgm.browser.enable;
  printing = c.services.printing.enable;
  ai = c.programs.nix-ld.enable;
  graphics = c.hardware.graphics.enable && c.hardware.graphics.enable32Bit;
  steam = c.programs.steam.enable;
  gamescope = c.programs.steam.gamescopeSession.enable;
  gamescopeTty = c.orgm.gaming.gamescopeTty1.enable;
  remotePlay = c.programs.steam.remotePlay.openFirewall;
  dedicatedServer = c.programs.steam.dedicatedServer.openFirewall;
  emulators = c.orgm.gaming.emulators;
  deskflow = builtins.elem "org.deskflow.deskflow" (map (p: if builtins.isString p then p else p.appId) c.services.flatpak.packages);
  openrgb = c.services.hardware.openrgb.enable;
  openrgbNotify = (hm.systemd.user.services.openrgb-notify.Install.WantedBy or []) != [];
  directory = c.xdg.mime.defaultApplications."inode/directory";
  specialisations = builtins.attrNames c.specialisation;
  vms = builtins.attrNames c.virtualisation.oci-containers.containers;
  zram = c.zramSwap.enable;
  stockKernel = c.boot.kernelPackages.kernel.outPath == s.pkgs.linuxPackages.kernel.outPath;
  earlyGpu = c.boot.initrd.kernelModules;
  efi = c.boot.loader.systemd-boot.enable;
  timeout = c.boot.loader.timeout;
  mounts = builtins.mapAttrs (_: fs: { inherit (fs) fsType device options; }) c.fileSystems;
  luks = c.boot.initrd.luks.devices.cryptroot.device;
  mutable = c.users.mutableUsers;
  rootSsh = c.services.openssh.settings.PermitRootLogin;
  credentialsUnset = builtins.all (u:
    u.initialPassword == null && u.initialHashedPassword == null &&
    u.hashedPassword == null && u.password == null && u.hashedPasswordFile == null
  ) [ c.users.users.osmarg c.users.users.root ];
  sops = hm.sops.age.keyFile;
}'''
# Resolve relative imports in the projection from the repository root.
result = subprocess.run([
    "nix", "eval", "--impure", "--json", f"path:{root}#nixosConfigurations.x13",
    "--apply", projection,
], cwd=root, text=True, capture_output=True)
assert hardware.read_bytes() == before, "evaluation changed generated hardware"
assert result.returncode == 0, result.stderr
c = json.loads(result.stdout)
assert (c["host"], c["context"]["user"], c["context"]["profile"]) == ("x13", "osmarg", "gnome")
assert c["programs"] == c["expectedPrograms"]
assert sorted(c["webapps"]) == sorted(c["expectedWebapps"])
assert c["autostart"] == c["expectedAutostart"]
assert not any("nextcloud" in p.lower() for p in c["programs"] + c["autostart"] + c["packages"] + c["hmPackages"])
assert set(c["expectedFlatpaks"]) <= set(c["flatpaks"])
assert "ai.storyteller.artcraft-launcher" in c["flatpaks"]
assert len(c["artcraft"]) == 1
assert c["artcraft"][0]["sha256"] == "08fc5d5ec7498292b238ff7ea0bfdd0d880f282cefb64a9980db135f3db95f8b"
assert c["artcraft"][0]["bundle"].startswith("/nix/store/")
assert c["failedAssertions"] == []
assert all(c[k] for k in ("artcraftIntegrations", "systemdInitrd", "noEmbeddedLuksKey", "accountRecovery"))
assert {"org.libretro.RetroArch", "org.DolphinEmu.dolphin-emu", "org.duckstation.DuckStation", "org.ppsspp.PPSSPP", "net.pcsx2.PCSX2", "info.cemu.Cemu", "io.github.ryubing.Ryujinx", "net.rpcs3.RPCS3", "net.shadps4.shadPS4"} <= set(c["flatpaks"])
assert not c["systemExtensions"]
assert sorted(c["userExtensions"]) == sorted(c["expectedExtensions"])
assert not c["enabledExtensions"]
assert all(c[k] for k in ("gnome", "goa", "browser", "printing", "ai", "graphics", "steam", "deskflow", "zram", "stockKernel", "efi", "mutable", "credentialsUnset"))
assert c["session"] == "gnome"
assert c["gdm"] and not c["sddm"]
assert not c["lockDisabled"] and c["lockEnabled"]
assert c["lockBinding"] == "@as ['<Super>l']"
assert "thunar" not in c["packages"] + c["hmPackages"]
assert {"nautilus", "gnome-text-editor", "loupe", "evince", "gnome-console"} <= set(c["packages"])
assert {"kitty", "orgmai"} <= set(c["packages"] + c["hmPackages"])
assert not any(c[k] for k in ("gamescope", "gamescopeTty", "remotePlay", "dedicatedServer", "openrgb", "openrgbNotify", "vms"))
assert c["specialisations"] == ["server"]
assert c["emulators"] == {"tier": "all", "backend": "flatpak"}
assert c["directory"] == "org.gnome.Nautilus.desktop"
assert "i915" in c["earlyGpu"]
assert c["timeout"] == 1, f"boot menu must be 1 second, got {c['timeout']}"
assert c["rootSsh"] == "no"
assert c["sops"] == "/home/osmarg/.config/sops/age/keys.txt"
assert c["luks"] == "/dev/disk/by-uuid/dde6b70b-af6f-4eba-8cd0-8825ddcb5968"
for mount, subvol in {"/": "@", "/home": "@home", "/nix": "@nix", "/var/log": "@log", "/.snapshots": "@snapshots"}.items():
    fs = c["mounts"][mount]
    assert (fs["fsType"], fs["device"]) == ("btrfs", "/dev/mapper/cryptroot")
    assert {f"subvol={subvol}", "compress=zstd", "noatime"} <= set(fs["options"])
assert c["mounts"]["/boot"]["fsType"] == "vfat"
assert c["mounts"]["/boot"]["device"] == "/dev/disk/by-partuuid/5512d8ef-bc51-4ea9-a3f6-cf575351fa72", "EFI mount must use the observed stable partition identity"
for name in ("default.nix", "gnome.nix"):
    source = (root / "nixos/hosts/x13" / name).read_text()
    assert not re.search(r"(?i)(password|authorizedKeys|privateKey)\s*=", source)
print("PASS: x13 isolated GNOME, osmarg selection, user extensions, gaming, storage and security")
print("Hardware SHA256:", hashlib.sha256(before).hexdigest())
