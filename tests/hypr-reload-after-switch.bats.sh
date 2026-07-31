#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$repo_dir/dotfiles/config/profiles/hyprland/.local/bin/hypr-reload-after-switch"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

runtime="$tmp/runtime"
home="$tmp/home"
bin="$tmp/bin"
socket="$runtime/hypr/live/.socket.sock"
mkdir -p "$(dirname "$socket")" "$home/.local/bin" "$home/.config/waybar-hypr" "$bin"

python3 - "$socket" <<'PY' &
import socket
import sys
import time

server = socket.socket(socket.AF_UNIX)
server.bind(sys.argv[1])
time.sleep(10)
PY
socket_pid=$!
trap 'kill "$socket_pid" 2>/dev/null || true; rm -rf "$tmp"' EXIT
until [ -S "$socket" ]; do sleep 0.01; done

cat >"$bin/hyprctl" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == '-j monitors' ]]; then
  printf '[]\n'
  exit 0
fi
printf '%s:%s\n' "$HYPRLAND_INSTANCE_SIGNATURE" "$*" >>"$HYPRCTL_CALLS"
EOF
cat >"$home/.local/bin/waybar-watch" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$bin/hyprctl" "$home/.local/bin/waybar-watch"

HOME="$home" XDG_RUNTIME_DIR="$runtime" PATH="$bin:$PATH" HYPRCTL_CALLS="$tmp/calls" "$script"
grep -Fxq 'live:reload' "$tmp/calls"
grep -Fxq "live:dispatch exec $home/.local/bin/waybar-watch $home/.config/waybar-hypr" "$tmp/calls"
printf '%s\n' 'hypr-reload-after-switch: ok'
