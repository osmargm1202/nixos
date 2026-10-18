#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RYOKU_TEST_REPO="$ROOT" nix eval --impure --json --expr '
let f=builtins.getFlake ("path:"+builtins.getEnv "RYOKU_TEST_REPO");
 describe = c: let u=c.systemd.user.services.envy-windows; in {
  alloc=c.orgm.envy.windows; mode=c.orgm.envy.mode; marker=c.environment.etc."orgm/windows-vm-profile".text;
  modules=c.boot.kernelModules; modulePackages=map (p: p.name) c.boot.extraModulePackages;
  modprobe=c.boot.extraModprobeConfig; udev=c.services.udev.extraRules;
  packages=map (p: p.name) c.environment.systemPackages;
  manifest=c.system.build.envyWindowsManifest; compose=c.system.build.envyWindowsCompose;
  controller=c.system.build.envyWindowsController; service=u.serviceConfig;
  wanted=u.wantedBy; restart=u.restartIfChanged; stop=u.stopIfChanged;
  linger=c.users.users.osmarg.linger; groups=c.users.users.osmarg.extraGroups;
  prep=c.systemd.services.envy-windows-storage.serviceConfig;
  mount=c.systemd.services.envy-windows-storage.unitConfig.RequiresMountsFor;
  files=builtins.attrNames c.home-manager.users.osmarg.home.file;
  env=c.home-manager.users.osmarg.home.sessionVariables;
 };
 c=f.nixosConfigurations.envy.config;
in {normal=describe c; modes=builtins.mapAttrs (_: s: describe s.configuration) c.specialisation;}
' | python3 -c '
import json,sys
v=json.load(sys.stdin)
for name,c in {"normal":v["normal"],**v["modes"]}.items():
 auto=name in ("windows-vfio","server")
 assert c["wanted"]==(["default.target"] if auto else []),name
 assert c["marker"].strip()==("envy-vfio" if auto else "envy-disabled" if name=="gaming" else "envy-render-node")
 assert c["alloc"]=={"memoryMiB":4096,"cpus":4,"diskGiB":96,"vramMiB":1024}
 assert ("kvmfr" in c["modules"])==auto,name
 assert any("kvmfr" in p for p in c["modulePackages"])==auto,name
 assert any(p.startswith("looking-glass-client-B7-544") for p in c["packages"])==auto,name
 if auto:
  assert "options kvmfr static_size_mb=128" in c["modprobe"],name
  assert "KERNEL==\"kvmfr0\", GROUP=\"kvm\", MODE=\"0660\"" in c["udev"],name
 assert c["linger"] and {"kvm","render","video","podman"}.issubset(c["groups"])
 assert not c["restart"] and not c["stop"]
 s=c["service"]
 assert s["RuntimeDirectoryPreserve"]=="yes"
 assert s["Type"]=="notify" and s["TimeoutStopSec"]=="infinity" and s["KillMode"]=="process"
 assert s["ExecStart"].startswith(c["controller"]+"/libexec/")
 assert c["mount"]=="/var/lib/windows" and c["prep"]["Type"]=="oneshot"
 assert "Apps/windows/envy/compose.yml" in c["files"]
 assert c["env"]["WINDOWS_RDP_ENVY_WINDOWS_PASSWORD_FILE"]=="/home/osmarg/.config/envy-windows/password"
 assert "PASSWORD" not in c["env"] and "WINDOWS_PASSWORD" not in c["env"]
print("PASS: Envy immutable Windows wiring and safe user lifecycle in all modes")
'

RYOKU_TEST_REPO="$ROOT" nix eval --impure --json --expr '
let f=builtins.getFlake ("path:"+builtins.getEnv "RYOKU_TEST_REPO");
 t=f.nixosConfigurations.envy.options.orgm.envy.windows.vramMiB.type;
in {valid=map t.check [256 512 1024 2048 4096]; invalid=t.check 768;}
' | python3 -c 'import json,sys; v=json.load(sys.stdin); assert all(v["valid"]) and not v["invalid"], "renderer requires power-of-two VRAM"'
