#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Evaluate one host at a time: forcing all module graphs together can exhaust
# RAM on the target laptops and obscure the result with swap thrashing.
for host in envy lenovo; do
RYOKU_TEST_REPO="$ROOT" WINDOWS_TEST_HOST="$host" nix eval --impure --json --expr '
 let f=builtins.getFlake ("path:"+builtins.getEnv "RYOKU_TEST_REPO");
 describe = host: c: let
   name=if host=="envy" then "envy-windows" else "lenovo-windows-autostart";
   u=c.systemd.user.services.${name};
   manager=c.systemd.services."user@1000".serviceConfig;
 in {
   controller=c.system.build.windowsVmController;
   installed=builtins.any (p: p.name == "windows-vm-controller-${host}") c.environment.systemPackages;
   service=u.serviceConfig;
   restart=u.restartIfChanged; stop=u.stopIfChanged;
   outerTimeout=manager.TimeoutStopSec or null;
   outerKill=manager.SendSIGKILL or null;
   outerMemlock=manager.LimitMEMLOCK or null;
   vfio=if host=="envy" then c.orgm.envy.windowsVfio.enable else c.orgm.lenovo.windowsVfio.enable;
 };
 all = host: let c=f.nixosConfigurations.${host}.config; in
   {normal=describe host c;} // builtins.mapAttrs (_: s: describe host s.configuration) c.specialisation;
 in let host=builtins.getEnv "WINDOWS_TEST_HOST"; in { ${host}=all host; }
' | python3 -c '
import json,sys
for host,modes in json.load(sys.stdin).items():
 for mode,c in modes.items():
  assert c["installed"],(host,mode)
  assert not c["restart"] and not c["stop"],(host,mode)
  s=c["service"]
  assert s["Type"]=="notify" and s["KillMode"]=="process" and not s["SendSIGKILL"],(host,mode)
  assert s["TimeoutStopSec"]=="infinity" and s["RuntimeDirectoryPreserve"]=="yes",(host,mode)
  assert s["ExecStart"]==c["controller"]+"/libexec/windows-vm-supervise",(host,mode)
  assert c["outerTimeout"]=="infinity" and c["outerKill"] is False,(host,mode,"outer manager must not kill guest at 120s")
  if c["vfio"]:assert c["outerMemlock"]=="infinity",(host,mode)
print("PASS: common controller and inner/outer graceful-shutdown guards for",host)
'
done
