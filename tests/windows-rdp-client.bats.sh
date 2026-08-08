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
cat >"$bin/docker" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  start) exit 0 ;;
  inspect)
    if [[ "$3" == *State.Running* ]]; then
      printf '%s\n' false
    else
      printf '%s\n' 'exited (exit 1)'
    fi
    ;;
  logs) printf '%s\n' 'simulated QEMU failure' ;;
esac
EOF
cat >"$bin/sdl-freerdp" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "sdl-freerdp $*" >"$RDP_LOG"
EOF
cat >"$bin/wlfreerdp" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "wlfreerdp $*" >"$RDP_LOG"
EOF
cat >"$bin/xfreerdp" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "xfreerdp $*" >"$RDP_LOG"
EOF
cat >"$bin/hyprctl" <<'EOF'
#!/usr/bin/env bash
if [[ "$1 $2" == "-j monitors" ]]; then
  printf '%s\n' '[{"focused":true,"width":1600,"height":900}]'
fi
EOF
cat >"$bin/jq" <<'EOF'
#!/usr/bin/env bash
[[ "$*" == *focused* ]] && printf '%s\n' '1600x900'
EOF
chmod +x "$bin"/*

wayland_log="$tmp/wayland.log"
HOME="$tmp/home" PATH="$bin:/usr/bin:/bin" WAYLAND_DISPLAY=wayland-1 DISPLAY=:0 RDP_LOG="$wayland_log" "$helper" connect
[[ "$(<"$wayland_log")" == "sdl-freerdp /v:localhost:3389"* ]]
[[ "$(<"$wayland_log")" == *"/gdi:sw"* ]]
[[ "$(<"$wayland_log")" == *"/size:1600x900"* ]]
[[ "$(<"$wayland_log")" != *"/f"* ]]
[[ "$(<"$wayland_log")" != *"-grab-keyboard"* ]]
[[ "$(<"$wayland_log")" != *"/dynamic-resolution"* ]]

x11_log="$tmp/x11.log"
HOME="$tmp/home" PATH="$bin:/usr/bin:/bin" WAYLAND_DISPLAY= DISPLAY=:0 RDP_LOG="$x11_log" "$helper" connect
[[ "$(<"$x11_log")" == "xfreerdp /v:localhost:3389"* ]]
[[ "$(<"$x11_log")" == *"/gdi:sw"* ]]
[[ "$(<"$x11_log")" == *"/size:1600x900"* ]]
[[ "$(<"$x11_log")" == *"/f"* ]]
[[ "$(<"$x11_log")" != *"-grab-keyboard"* ]]
[[ "$(<"$x11_log")" != *"/dynamic-resolution"* ]]
failure_profile="$tmp/render-node-profile"
printf '%s\n' render-node >"$failure_profile"
failure_output="$(HOME="$tmp/home" PATH="$bin:/usr/bin:/bin" WINDOWS_VM_PROFILE_FILE="$failure_profile" "$helper" start 2>&1 || true)"
[[ "$failure_output" == *"Container 'windows' failed: exited (exit 1)."* ]]
[[ "$failure_output" == *'simulated QEMU failure'* ]]


profile_file="$tmp/windows-vm-profile"
printf '%s\n' lenovo-vfio >"$profile_file"
vfio_status="$(HOME="$tmp/home" PATH="$bin:/usr/bin:/bin" WAYLAND_DISPLAY= DISPLAY=:0 WINDOWS_VM_PROFILE_FILE="$profile_file" "$helper" status)"
grep -Fqx 'profile=lenovo-vfio' <<<"$vfio_status"
grep -Fqx 'container=lenovo-windows' <<<"$vfio_status"
grep -Fqx 'client=xfreerdp ' <<<"$vfio_status"

non_vfio_profile="$tmp/non-vfio-profile"
printf '%s\n' render-node >"$non_vfio_profile"
non_vfio_lg_output="$(HOME="$tmp/home" PATH="$bin:/usr/bin:/bin" WINDOWS_VM_PROFILE_FILE="$non_vfio_profile" "$helper" looking-glass 2>&1 || true)"
[[ "$non_vfio_lg_output" == *"Looking Glass is available only for the Lenovo VFIO Windows profile."* ]]

printf '%s\n' 'windows-rdp-client: ok'
