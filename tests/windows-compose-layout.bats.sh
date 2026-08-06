#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
compose_dir="$repo_dir/containers/windows"
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
[[ "$render_node" == *'/tmp/windows-storage:/storage'* ]]

lenovo_vfio="$(render -f "$compose_dir/compose.yml" -f "$compose_dir/hosts/lenovo-windows/compose.yml")"
[[ "$lenovo_vfio" == *'container_name: lenovo-windows'* ]]
[[ "$lenovo_vfio" == *'/dev/vfio/vfio'* ]]
[[ "$lenovo_vfio" == *'/dev/vfio/16'* ]]
[[ "$lenovo_vfio" == *'vfio-pci,host=01:00.0'* ]]
[[ "$lenovo_vfio" == *'group_add:'* ]]
[[ "$lenovo_vfio" == *'keep-groups'* ]]
[[ "$lenovo_vfio" != *'/dev/dri'* ]]

printf '%s\n' 'windows-compose-layout: ok'
