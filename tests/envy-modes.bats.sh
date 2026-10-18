#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RYOKU_TEST_REPO="$ROOT" nix eval --impure --json --expr '''
let f=builtins.getFlake ("path:"+builtins.getEnv "RYOKU_TEST_REPO");
 describe = c:  {
   managerMemlock=c.systemd.services."user@1000".serviceConfig.LimitMEMLOCK or "unset"; mode=c.orgm.envy.mode or "missing"; vfio=c.orgm.envy.windowsVfio.enable or false;
   kernel=c.boot.kernelPackages.kernel.version; driver=c.hardware.nvidia.package.version;
   video=c.services.xserver.videoDrivers; initrd=c.boot.initrd.kernelModules; params=c.boot.kernelParams;
   blacklist=c.boot.blacklistedKernelModules; offload=c.hardware.nvidia.prime.offload.enable;
   cdi=c.hardware.nvidia-container-toolkit.enable; ryoku=c.programs.ryoku.enable or false;
   hypr=c.programs.hyprland.enable; niri=c.programs.niri.enable;
   sddm=c.services.displayManager.sddm.enable; autologin=c.services.displayManager.autoLogin.enable;
   gaming=c.orgm.gaming.gamescopeTty1.enable; target=c.systemd.defaultUnit;
   ssh=c.services.openssh.enable; network=c.networking.networkmanager.enable;
   tailscale=c.services.tailscale.enable; sunshine=c.services.sunshine.enable;
   login=c.programs.bash.loginShellInit; timeout=c.boot.loader.timeout;
   sort=c.boot.loader.systemd-boot.sortKey; extraInstall=c.boot.loader.systemd-boot.extraInstallCommands;
   marker=c.environment.etc."orgm/desktop-profile".text;
   assertionFailures=map (a: a.message) (builtins.filter (a: !a.assertion) c.assertions);
 };
 c=f.nixosConfigurations.envy.config;
in {hosts=builtins.attrNames f.nixosConfigurations; normal=describe c;
 modes=builtins.mapAttrs (_: s: describe s.configuration) c.specialisation;}
''' | python3 -c '''
import json,sys
v=json.load(sys.stdin)
assert sorted(v["modes"])==["gaming","server","windows-vfio"], "missing Envy internal modes"
assert sorted(v["hosts"])==["envy","ero","jarq","lenovo","orgm"]
for name,c in {"normal":v["normal"],**v["modes"]}.items():
 assert not c["assertionFailures"],(name,c["assertionFailures"])
 assert c["timeout"]==1 and c["kernel"].startswith("6.12.") and c["driver"].startswith("580."),name
 assert "i915" in c["initrd"] and c["ssh"] and c["network"] and c["tailscale"],name
 assert "video=eDP-1:d" not in c["params"],name
 assert not any("acs_override" in p or "unsafe_interrupts" in p or "10de:1fbb" in p for p in c["params"]),name
 assert "set-server-boot-default" not in c["extraInstall"],name
 graphics=name in ("normal","windows-vfio")
 assert c["ryoku"]==graphics and c["sddm"]==graphics and c["hypr"]==graphics and c["niri"]==graphics,name
 assert not c["autologin"],name
 vfio=name in ("windows-vfio","server")
 assert c["vfio"]==vfio and c["offload"]== (not vfio) and c["cdi"]== (not vfio),name
 if vfio:
  assert c["managerMemlock"]=="infinity",name
  assert "vfio-pci.ids=10de:1d13" in c["params"] and "intel_iommu=on" in c["params"],name
  assert "nvidia" not in c["video"] and "nvidia" in c["blacklist"] and "vfio_pci" in c["initrd"],name
 else: assert not any(p.startswith("vfio-pci.ids=") for p in c["params"]),name
 assert c["gaming"]==(name=="gaming"),name
 if name=="gaming": assert "nvidia-game gamescope" in c["login"] and "steam -gamepadui" in c["login"]
 if name=="server": assert c["target"]=="multi-user.target" and not c["sunshine"]
assert v["normal"]["mode"]=="normal" and v["normal"]["sort"]=="nixos-00-normal"
print("PASS: Envy mode GPU ownership, console isolation, preserved recovery and normal default")
'''
