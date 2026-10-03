#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
compose_dir="$repo_dir/nixos/containers/windows"
common_env=(
  WINDOWS_PASSWORD=verification-password
  WINDOWS_SHARED_DIR=/tmp/windows-shared
  WINDOWS_STORAGE_DIR=/tmp/windows-storage
  WINDOWS_OEM_DIR=/tmp/windows-oem
)

render() {
  (
    cd "$compose_dir"
    env "${common_env[@]}" docker compose "$@" config
  )
}

render_node="$(render -f compose.yml -f compose.render-node.yml)"
[[ "$render_node" == *'image: dockurr/windows:latest'* ]]
[[ "$render_node" == *'/dev/kvm'* ]]
[[ "$render_node" == *'/dev/net/tun'* ]]
[[ "$render_node" == *'/dev/dri'* ]]
[[ "$render_node" != *'/dev/vfio/'* ]]
env "${common_env[@]}" docker compose -f "$compose_dir/compose.yml" \
  -f "$compose_dir/compose.render-node.yml" config --format json | python3 -c '
import json, sys
windows = json.load(sys.stdin)["services"]["windows"]
assert any(v["source"] == "/tmp/windows-storage" and v["target"] == "/storage"
           for v in windows["volumes"]), windows["volumes"]
'

lenovo_vfio="$(render -f "$compose_dir/compose.yml" -f "$compose_dir/hosts/lenovo-windows/compose.yml")"
[[ "$lenovo_vfio" == *'container_name: lenovo-windows'* ]]
[[ "$lenovo_vfio" == *'/dev/vfio/vfio'* ]]
[[ "$lenovo_vfio" == *'/dev/vfio/16'* ]]
[[ "$lenovo_vfio" == *'vfio-pci,host=01:00.0'* ]]
[[ "$lenovo_vfio" == *'intel-iommu,intremap=on,caching-mode=on,aw-bits=39'* ]]
[[ "$lenovo_vfio" == *'group_add:'* ]]
[[ "$lenovo_vfio" == *'keep-groups'* ]]
[[ "$lenovo_vfio" != *'/dev/dri'* ]]

# Exercise the deployed Home Manager layout: Compose files and Dockerfile are
# links into the store, while the builder must receive a regular file.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export WINDOWS_TEST_REPO="$repo_dir"
build_context="$(nix build --impure --no-link --print-out-paths --expr '
  let
    flake = builtins.getFlake ("path:" + builtins.getEnv "WINDOWS_TEST_REPO");
    vfio = flake.nixosConfigurations.lenovo-ryoku.config.specialisation.windows-vfio.configuration;
  in builtins.dirOf vfio.home-manager.users.osmarg.home.file."Apps/windows/Containerfile.spice".source
')"
[[ -f "$build_context/Containerfile.spice" && ! -L "$build_context/Containerfile.spice" ]]
nix eval --impure --raw --expr '
  let
    flake = builtins.getFlake ("path:" + builtins.getEnv "WINDOWS_TEST_REPO");
    vfio = flake.nixosConfigurations.lenovo-ryoku.config.specialisation.windows-vfio.configuration;
  in vfio.home-manager.users.osmarg.home.file."Apps/windows/compose.lenovo-vfio.yml".text
' > "$tmp/deployed-overlay.yml"
mkdir "$tmp/project"
ln -s "$compose_dir/compose.yml" "$tmp/project/compose.yml"
ln -s "$tmp/deployed-overlay.yml" "$tmp/project/compose.lenovo-vfio.yml"
ln -s "$build_context/Containerfile.spice" "$tmp/project/Containerfile.spice"
env "${common_env[@]}" docker compose -f "$tmp/project/compose.yml" \
  -f "$tmp/project/compose.lenovo-vfio.yml" config --format json > "$tmp/deployed.json"
python3 - "$tmp/deployed.json" "$build_context" <<'PY'
import json
from pathlib import Path
import sys
windows = json.loads(Path(sys.argv[1]).read_text())['services']['windows']
assert windows['build']['context'] == sys.argv[2], windows['build']
assert windows['build']['dockerfile'] == 'Containerfile.spice'
assert any(v['source'] == '/tmp/windows-storage' and v['target'] == '/storage'
           for v in windows['volumes']), windows['volumes']
assert windows['group_add'] == ['keep-groups'], windows['group_add']
PY

printf '%s\n' 'windows-compose-layout: ok'
