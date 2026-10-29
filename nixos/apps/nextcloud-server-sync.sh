# Loaded by pkgs.writeShellApplication; credentials come from EnvironmentFile.

can_sync() {
  local profile
  if [[ ! -r /etc/orgm/desktop-profile ]]; then
    return 1
  fi
  read -r profile < /etc/orgm/desktop-profile
  [[ "$profile" == server ]] || return 1

  # Desktop autostart may launch the executable without its systemd unit.
  if systemctl --user --quiet is-active com.nextcloud.desktopclient.nextcloud.service ||
    pgrep -u "$UID" -f '(^|/)[.]?nextcloud(-wrapped)?([[:space:]]|$)' > /dev/null; then
    echo 'Skipping synchronization: the graphical Nextcloud client is running.'
    return 1
  fi
}

if [[ "${1:-}" == --check ]]; then
  can_sync
  exit "$?"
fi

can_sync || exit 0
: "${NC_URL:?Missing NC_URL in nextcloud-server.env}"
: "${NC_USER:?Missing NC_USER in nextcloud-server.env}"
: "${NC_PASSWORD:?Missing NC_PASSWORD in nextcloud-server.env}"

if [[ "$NC_URL" != https://* ]]; then
  echo 'Nextcloud requires an HTTPS server URL.' >&2
  exit 1
fi

local_dir="$HOME/Nextcloud"
exclude_file="$HOME/.config/Nextcloud/sync-exclude.lst"
if [[ ! -d "$local_dir" || ! -r "$exclude_file" ]]; then
  echo 'The existing Nextcloud folder and exclusion list must be present.' >&2
  exit 1
fi

exec 9>"${XDG_RUNTIME_DIR:?}/nextcloud-server.lock"
flock --nonblock 9 || exit 0

echo 'Starting Nextcloud synchronization.'
nextcloudcmd --non-interactive --silent --exclude "$exclude_file" "$local_dir" "$NC_URL" &
sync_pid=$!
trap 'kill "$sync_pid" 2>/dev/null || true; wait "$sync_pid" 2>/dev/null || true' EXIT

# A large first sync may outlast a switch back to a graphical profile. Stop
# only this worker if the profile changes or the desktop client starts.
while kill -0 "$sync_pid" 2>/dev/null; do
  if ! can_sync; then
    echo 'Stopping server synchronization because the desktop profile or client changed.'
    exit 0
  fi
  sleep 5
done
wait "$sync_pid"
trap - EXIT
echo 'Nextcloud synchronization completed successfully.'
