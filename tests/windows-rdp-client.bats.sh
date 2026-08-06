#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
helper="$repo_dir/dotfiles/config/shared/.local/bin/windows-rdp"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
bin="$tmp/bin"
mkdir -p "$bin" "$tmp/home"

cat >"$bin/nc" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat >"$bin/sfreerdp" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${SDL_VIDEODRIVER:-} $0 $*" >"$RDP_LOG"
EOF
cat >"$bin/wlfreerdp" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "wlfreerdp $*" >"$RDP_LOG"
EOF
cat >"$bin/xfreerdp" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "xfreerdp $*" >"$RDP_LOG"
EOF
chmod +x "$bin"/*

wayland_log="$tmp/wayland.log"
HOME="$tmp/home" PATH="$bin:/usr/bin:/bin" WAYLAND_DISPLAY=wayland-1 DISPLAY=:0 RDP_LOG="$wayland_log" "$helper" connect
[[ "$(<"$wayland_log")" == "wayland $bin/sfreerdp /v:localhost:3389"* ]]

x11_log="$tmp/x11.log"
HOME="$tmp/home" PATH="$bin:/usr/bin:/bin" WAYLAND_DISPLAY= DISPLAY=:0 RDP_LOG="$x11_log" "$helper" connect
[[ "$(<"$x11_log")" == "xfreerdp /v:localhost:3389"* ]]

profile_file="$tmp/windows-vm-profile"
printf '%s\n' lenovo-vfio >"$profile_file"
vfio_status="$(HOME="$tmp/home" PATH="$bin:/usr/bin:/bin" WAYLAND_DISPLAY= DISPLAY=:0 WINDOWS_VM_PROFILE_FILE="$profile_file" "$helper" status)"
grep -Fqx 'profile=lenovo-vfio' <<<"$vfio_status"
grep -Fqx 'container=lenovo-windows' <<<"$vfio_status"
grep -Fqx 'client=xfreerdp ' <<<"$vfio_status"

printf '%s\n' 'windows-rdp-client: ok'
