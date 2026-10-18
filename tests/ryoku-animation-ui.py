#!/usr/bin/env python3
"""Run the actual animation page offscreen with a slow/failing backend."""
from pathlib import Path
import os
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
expr = """let f=builtins.getFlake ("path:"+builtins.getEnv "RYOKU_TEST_REPO");
  p=(import (builtins.getEnv "RYOKU_TEST_REPO"+"/nixos/profiles/ryoku/provider-compat.nix")
    {inputs=f.inputs;pkgs=f.nixosConfigurations.lenovo.pkgs;lib=f.inputs.nixpkgs.lib;}).packages;
  qs=f.inputs.nixpkgs.lib.findFirst (p: f.inputs.nixpkgs.lib.getName p == "ryoku-qs")
    (throw "Ryoku Quickshell launcher missing") f.nixosConfigurations.lenovo.config.systemd.user.services.ryoku-shell.path;
  in [p.ryoku-desktop-data qs]"""
packages = subprocess.check_output(["nix", "build", "--impure", "--no-link", "--print-out-paths", "--expr", expr],
    env=dict(os.environ, RYOKU_TEST_REPO=str(ROOT)), text=True).splitlines()
DATA = next(Path(p) for p in packages if (Path(p)/"share/ryoku/config").is_dir())
LAUNCHER = next(Path(p)/"bin/ryoku-qs" for p in packages if (Path(p)/"bin/ryoku-qs").is_file())
with tempfile.TemporaryDirectory() as tmp:
 p=Path(tmp);(p/'run').mkdir(mode=0o700);(p/'bin').mkdir()
 fake=p/'bin/ryoku-hub'
 fake.write_text('''#!/usr/bin/env python3
import sys,json,time,pathlib,os
if sys.argv[1:3]==['desktop','anim-preset']:
 if len(sys.argv)==3: print('{"preset":"ryoku"}')
 else:
  time.sleep(0.08)
  if sys.argv[3]=='rage': print('test backend rejected preset',file=sys.stderr);sys.exit(1)
  with open(os.environ['TEST_CALLS'],'a') as f:f.write(sys.argv[3]+'\\n')
else: print('{}')
''');fake.chmod(0o755)
 q=p/'test.qml'
 q.write_text('''import QtQuick
import Quickshell
import "'''+'file:'+str(DATA/'share/ryoku/config/quickshell/hub/pages')+'''" as Pages
ShellRoot {
 id: root
 property int stage: 0
 property int count: 0
 Pages.AnimationsPage { id: page }
 Timer {
  interval: 30; repeat: true; running: true
  onTriggered: {
   root.count++;
   if(root.count > 150) { console.log("FAIL timeout"); Qt.quit(); }
   if(root.stage === 0 && root.count > 5) {
    page.setAnimPreset("fade"); page.setAnimPreset("fast"); root.stage=1;
   } else if(root.stage===1 && page.animPresetApplying==="" && page.animPreset==="fast") {
    page.setAnimPreset("rage"); root.stage=2;
   } else if(root.stage===2 && page.animPresetApplying==="" && page.animPresetError!=="") {
    if(page.animPreset!=="fast") { console.log("FAIL failed preset changed selection"); Qt.quit(); return; }
    page.setAnimPreset("rage"); page.setAnimPreset("bounce"); root.stage=3;
   } else if(root.stage===3 && page.animPresetApplying==="" && page.animPreset==="bounce") {
    if(page.animPresetError!=="") { console.log("FAIL stale error after queued success");Qt.quit();return; }
    console.log("PASS queued presets and backend errors");Qt.quit();
   }
  }
 }
}
''')
 env=dict(os.environ,HOME=str(p),XDG_CONFIG_HOME=str(p/'config'),XDG_CACHE_HOME=str(p/'cache'),XDG_RUNTIME_DIR=str(p/'run'),QT_QPA_PLATFORM='offscreen',QSG_RHI_BACKEND='software',PATH=str(p/'bin')+':'+os.environ['PATH'],TEST_CALLS=str(p/'calls'))
 for k in ('HYPRLAND_INSTANCE_SIGNATURE','WAYLAND_DISPLAY','DISPLAY'):env.pop(k,None)
 r=subprocess.run([str(LAUNCHER),'-p',str(q)],env=env,capture_output=True,text=True,timeout=15)
 logs = r.stdout + r.stderr
 assert r.returncode == 0 and "PASS queued presets and backend errors" in logs, logs
 assert "FAIL" not in logs, logs
 assert (p/'calls').read_text().splitlines() == ['fade', 'fast', 'bounce'], logs
 print("PASS: real QML page queues rapid selections and reports backend failures without changing the selected preset")
