#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"
export WINDOWS_TEST_REPO="$repo_dir"
# Resolve real Docker Compose, not the `docker` compatibility shim for Podman.
compose_pkg="$(nix build --impure --no-link --print-out-paths --expr '
 let f=builtins.getFlake ("path:"+builtins.getEnv "WINDOWS_TEST_REPO");
 in f.nixosConfigurations.envy.pkgs.docker-compose
')"
export DOCKER_COMPOSE="$compose_pkg/bin/docker-compose"
inventory="$(nix build --impure --no-link --print-out-paths --expr '
 let f=builtins.getFlake ("path:"+builtins.getEnv "WINDOWS_TEST_REPO");
 c=f.nixosConfigurations.lenovo.config; v=c.specialisation.windows-vfio.configuration;
 in f.nixosConfigurations.envy.pkgs.writeText "windows-compose-tests.json" (builtins.toJSON {
  render=c.system.build.windowsVmManifest; vfio=v.system.build.windowsVmManifest;
  deployed=v.home-manager.users.osmarg.home.file."Apps/windows/compose.lenovo-vfio.yml".text;
 })
')"
python3 - "$inventory" <<'PY'
import json, os, subprocess, sys, tempfile
from pathlib import Path
inventory=json.loads(Path(sys.argv[1]).read_text())
assert '/dev/vfio/16' not in inventory['deployed']
assert 'build:' not in inventory['deployed']
assert 'USB: "yes"' in inventory['deployed'] and 'MOUSE: "virtio-mouse-pci"' in inventory['deployed']
for mode in ('render','vfio'):
 m=json.loads(Path(inventory[mode]).read_text())
 env=dict(os.environ, WINDOWS_PASSWORD='fixture-only', WINDOWS_STORAGE_DIR='/tmp/windows-storage',
          WINDOWS_SHARED_DIR='/tmp/windows-shared', WINDOWS_OEM_DIR='/tmp/windows-oem')
 devices=['/dev/kvm','/dev/net/tun']
 if mode=='vfio':devices+=['/dev/vfio/vfio','/dev/vfio/71','/dev/kvmfr0']
 else:devices+=['/dev/dri/renderD173']
 service={'image':m['image'],'container_name':m['container'],'pull_policy':'never','devices':devices}
 with tempfile.TemporaryDirectory() as d:
  overlay=Path(d)/'hardware.json';overlay.write_text(json.dumps({'services':{'windows':service}}))
  files=[arg for file in m['compose']+[str(overlay)] for arg in ('-f',file)]
  value=json.loads(subprocess.check_output([os.environ['DOCKER_COMPOSE'],*files,'config','--format','json'],env=env,text=True))
  w=value['services']['windows']
  assert w['image']==m['image'] and w['pull_policy']=='never' and 'build' not in w
  assert w['container_name']==('lenovo-windows' if mode=='vfio' else 'windows')
  assert any(v['source']=='/tmp/windows-storage' and v['target']=='/storage' for v in w['volumes'])
  paths=[v['source'] for v in w['devices']]
  assert '/dev/vfio/16' not in paths and '/dev/dri' not in paths
  assert ('/dev/vfio/71' in paths)==(mode=='vfio')
  assert ('/dev/dri/renderD173' in paths)==(mode=='render')
  assert 'keep-groups' in w['group_add']
  if mode=='vfio':
   a=w['environment']['ARGUMENTS']
   assert 'vfio-pci,host=01:00.0' in a
   assert 'intel-iommu,intremap=on,caching-mode=on,aw-bits=39' in a
   assert 'mem-path=/dev/kvmfr0,size=134217728' in a
   assert any(p['target']==5901 and p['host_ip']=='127.0.0.1' for p in w['ports'])
  subprocess.run(['podman-compose',*files,'config','-q'],env=env,check=True)
print('PASS: Lenovo deployed mode templates merge with dynamic devices and prepared images, never build at start')
PY
