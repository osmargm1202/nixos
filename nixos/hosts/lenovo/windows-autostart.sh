# An active VM needs no action. The host's GPU profile selects its runtime.
profile_file="${WINDOWS_VM_PROFILE_FILE:-/etc/orgm/windows-vm-profile}"
profile="$(<"$profile_file")"
case "$profile" in
  lenovo-vfio) container_name=lenovo-windows; other_container=windows ;;
  lenovo-render-node) container_name=windows; other_container=lenovo-windows ;;
  *) printf 'Unsupported Lenovo Windows profile: %s\n' "$profile" >&2; exit 1 ;;
esac

# The render-node VM shares the storage. Do not start a second QEMU if it is
# already using that disk, even if someone changed the host profile manually.
if podman container exists "$other_container"; then
  other_running="$(podman inspect --format '{{.State.Running}}' "$other_container")"
  if [[ "$other_running" == true ]]; then
    printf '%s\n' 'The other Windows VM is active; refusing concurrent disk access.' >&2
    exit 1
  fi
fi

if podman container exists "$container_name"; then
  running="$(podman inspect --format '{{.State.Running}}' "$container_name")"
  [[ "$running" != true ]] || exit 0
  exec podman start "$container_name"
fi

# This host currently only has the VFIO runtime. Provision the other runtime
# on its first non-VFIO boot, reusing the existing image, disk and .env. This
# never installs a new Windows OS, builds an image, or replaces a container.
if [[ "$profile" == lenovo-render-node ]]; then
  podman image exists localhost/local/dockurr-windows-spice:latest
  cd "${WINDOWS_COMPOSE_DIR:-$HOME/Apps/windows}"
  [[ -r .env ]] || { printf '%s\n' 'Windows .env is missing' >&2; exit 1; }
  exec podman-compose --env-file .env -f '@BASE_COMPOSE@' -f '@RENDER_COMPOSE@' \
    up -d --no-build --no-recreate windows
fi

printf '%s\n' 'The existing lenovo-windows VFIO container is missing.' >&2
exit 1
