#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
helper="$repo_dir/dotfiles/config/shared/.local/bin/windows-rdp"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
bin="$tmp/bin"
mkdir -p "$bin" "$tmp/home"
ln -s "$BASH" "$bin/bash"
ln -s "$(command -v grep)" "$bin/grep"

cat >"$bin/nc" <<'EOF'
#!/usr/bin/env bash
if [[ -n "${NC_LOG:-}" ]]; then
  printf '%q\n' "$@" >>"$NC_LOG"
fi
exit 0
EOF
cat >"$bin/docker" <<'EOF'
#!/usr/bin/env bash
if [[ -n "${DOCKER_LOG:-}" ]]; then
  printf '%s\n' "$*" >>"$DOCKER_LOG"
fi
running="${WINDOWS_TEST_RUNNING:-false}"
if [[ -n "${WINDOWS_TEST_STATE_FILE:-}" && -r "$WINDOWS_TEST_STATE_FILE" ]]; then
  read -r running <"$WINDOWS_TEST_STATE_FILE"
fi
case "$1" in
  start)
    if [[ -n "${WINDOWS_TEST_STATE_FILE:-}" ]]; then
      printf '%s\n' true >"$WINDOWS_TEST_STATE_FILE"
    fi
    exit 0
    ;;
  inspect)
    if [[ "$3" == *State.Running* ]]; then
      printf '%s\n' "$running"
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
cat >"$bin/looking-glass-client" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$LG_LOG"
EOF
cat >"$bin/notify-send" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$NOTIFY_LOG"
EOF
cat >"$bin/seq" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' 1
EOF
cat >"$bin/sleep" <<'EOF'
#!/usr/bin/env bash
:
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
chmod +x "$bin/nc" "$bin/docker" "$bin/sdl-freerdp" "$bin/wlfreerdp" "$bin/xfreerdp" "$bin/looking-glass-client" "$bin/notify-send" "$bin/seq" "$bin/sleep" "$bin/hyprctl" "$bin/jq"

wayland_log="$tmp/wayland.log"
HOME="$tmp/home" PATH="$bin:/usr/bin:/bin" WAYLAND_DISPLAY=wayland-1 DISPLAY=:0 RDP_LOG="$wayland_log" "$helper" connect
[[ "$(<"$wayland_log")" == "sdl-freerdp /v:localhost:3389"* ]]
[[ "$(<"$wayland_log")" == *"/gdi:sw"* ]]
[[ "$(<"$wayland_log")" == *"/size:1600x900"* ]]
[[ "$(<"$wayland_log")" != *"/f"* ]]
[[ "$(<"$wayland_log")" == *"-grab-keyboard"* ]]
[[ "$(<"$wayland_log")" != *"/dynamic-resolution"* ]]

x11_log="$tmp/x11.log"
HOME="$tmp/home" PATH="$bin:/usr/bin:/bin" WAYLAND_DISPLAY= DISPLAY=:0 RDP_LOG="$x11_log" "$helper" connect
[[ "$(<"$x11_log")" == "xfreerdp /v:localhost:3389"* ]]
[[ "$(<"$x11_log")" == *"/gdi:sw"* ]]
[[ "$(<"$x11_log")" == *"/size:1600x900"* ]]
[[ "$(<"$x11_log")" == *"/f"* ]]
[[ "$(<"$x11_log")" == *"-grab-keyboard"* ]]
[[ "$(<"$x11_log")" != *"/dynamic-resolution"* ]]

toggle_profile="$tmp/toggle-profile"
printf '%s\n' render-node >"$toggle_profile"
toggle_state="$tmp/toggle-state"
printf '%s\n' false >"$toggle_state"
toggle_log="$tmp/toggle.log"
HOME="$tmp/home" PATH="$bin:/usr/bin:/bin" WINDOWS_VM_PROFILE_FILE="$toggle_profile" WINDOWS_TEST_STATE_FILE="$toggle_state" DOCKER_LOG="$toggle_log" "$helper" toggle
grep -Fqx 'start windows' "$toggle_log"
HOME="$tmp/home" PATH="$bin:/usr/bin:/bin" WINDOWS_VM_PROFILE_FILE="$toggle_profile" WINDOWS_TEST_STATE_FILE="$toggle_state" DOCKER_LOG="$toggle_log" "$helper" toggle
grep -Fqx 'stop windows' "$toggle_log"
notify_log="$tmp/notifications.log"
printf '%s\n' false >"$toggle_state"
HOME="$tmp/home" PATH="$bin:/usr/bin:/bin" DISPLAY=:0 WINDOWS_VM_PROFILE_FILE="$toggle_profile" WINDOWS_TEST_STATE_FILE="$toggle_state" DOCKER_LOG="$toggle_log" NOTIFY_LOG="$notify_log" "$helper" toggle
grep -Fq "Windows iniciando! Iniciando contenedor 'windows'." "$notify_log"
grep -Fq "Windows iniciado Contenedor 'windows' y RDP listos." "$notify_log"
HOME="$tmp/home" PATH="$bin:/usr/bin:/bin" DISPLAY=:0 WINDOWS_VM_PROFILE_FILE="$toggle_profile" WINDOWS_TEST_STATE_FILE="$toggle_state" DOCKER_LOG="$toggle_log" NOTIFY_LOG="$notify_log" "$helper" toggle
grep -Fq "Windows apagando Deteniendo contenedor 'windows'." "$notify_log"
grep -Fq "Windows detenido Contenedor 'windows' detenido." "$notify_log"
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
lg_log="$tmp/looking-glass.log"
HOME="$tmp/home" PATH="$bin:/usr/bin:/bin" WINDOWS_VM_PROFILE_FILE="$profile_file" WINDOWS_TEST_RUNNING=true LG_LOG="$lg_log" "$helper" looking-glass
[[ "$(<"$lg_log")" == "-m 88 -p 5901" ]]
vfio_start_docker_log="$tmp/vfio-start-docker.log"
HOME="$tmp/home" PATH="$bin:/usr/bin:/bin" WINDOWS_VM_PROFILE_FILE="$profile_file" WINDOWS_TEST_RUNNING=true WINDOWS_COMPOSE_DIR="$repo_dir/containers/windows" DOCKER_LOG="$vfio_start_docker_log" "$helper" start
grep -Fqx 'compose --env-file .env -f compose.yml -f compose.lenovo-vfio.yml up -d --build' "$vfio_start_docker_log"

non_vfio_profile="$tmp/non-vfio-profile"
printf '%s\n' render-node >"$non_vfio_profile"
non_vfio_lg_output="$(HOME="$tmp/home" PATH="$bin:/usr/bin:/bin" WINDOWS_VM_PROFILE_FILE="$non_vfio_profile" "$helper" looking-glass 2>&1 || true)"
[[ "$non_vfio_lg_output" == *"Looking Glass is available only for the Lenovo VFIO Windows profile."* ]]

web_profile="$tmp/web-vm-profile"
printf '%s\n' lenovo-vfio >"$web_profile"

web_helper_bin="$tmp/web-helper-bin"
mkdir -p "$web_helper_bin"
ln -s "$BASH" "$web_helper_bin/bash"
cat >"$web_helper_bin/firefox-open-tab" <<'EOF'
#!/usr/bin/env bash
printf '%q\n' "$@" >"$WEB_LOG"
EOF
chmod +x "$web_helper_bin/firefox-open-tab"
web_start_profile="$tmp/web-start-vm-profile"
printf '%s\n' render-node >"$web_start_profile"
web_start_state="$tmp/web-start-state"
printf '%s\n' false >"$web_start_state"
web_start_log="$tmp/web-start.log"
web_start_docker_log="$tmp/web-start-docker.log"
web_start_nc_log="$tmp/web-start-nc.log"
HOME="$tmp/home" PATH="$web_helper_bin:$bin" WINDOWS_VM_PROFILE_FILE="$web_start_profile" WINDOWS_TEST_STATE_FILE="$web_start_state" WEB_LOG="$web_start_log" DOCKER_LOG="$web_start_docker_log" NC_LOG="$web_start_nc_log" "$helper" web
[[ "$(<"$web_start_log")" == $'--new\nhttp://127.0.0.1:8006' ]]
[[ "$(<"$web_start_docker_log")" == *"start windows"* ]]
[[ "$(<"$web_start_nc_log")" == $'-z\n127.0.0.1\n8006' ]]
web_helper_log="$tmp/web-helper.log"
web_helper_docker_log="$tmp/web-helper-docker.log"
web_helper_nc_log="$tmp/web-helper-nc.log"
web_helper_output="$(HOME="$tmp/home" PATH="$web_helper_bin:$bin" WINDOWS_VM_PROFILE_FILE="$web_profile" WINDOWS_TEST_RUNNING=true WEB_LOG="$web_helper_log" NC_LOG="$web_helper_nc_log" DOCKER_LOG="$web_helper_docker_log" "$helper" web)"
[[ "$web_helper_output" == *"Waiting for Windows Web Console on 127.0.0.1:8006..."* ]]
[[ "$web_helper_output" == *"Windows Web Console is ready."* ]]
[[ "$(<"$web_helper_log")" == $'--new\nhttp://127.0.0.1:8006' ]]
[[ "$(<"$web_helper_nc_log")" == $'-z\n127.0.0.1\n8006' ]]
[[ "$(<"$web_helper_docker_log")" == *"inspect --format {{.State.Running}} lenovo-windows"* ]]
[[ "$(<"$web_helper_docker_log")" != *"compose"* ]]

web_firefox_bin="$tmp/web-firefox-bin"
mkdir -p "$web_firefox_bin"
ln -s "$BASH" "$web_firefox_bin/bash"
cat >"$web_firefox_bin/firefox" <<'EOF'
#!/usr/bin/env bash
printf '%q\n' "$@" >"$WEB_LOG"
EOF
chmod +x "$web_firefox_bin/firefox"
web_firefox_log="$tmp/web-firefox.log"
HOME="$tmp/home" PATH="$web_firefox_bin:$bin" WINDOWS_TEST_RUNNING=true WEB_LOG="$web_firefox_log" "$helper" web
for _ in {1..10}; do
  [[ -f "$web_firefox_log" ]] && break
  sleep 0.1
done
[[ "$(<"$web_firefox_log")" == $'--new-tab\nhttp://127.0.0.1:8006' ]]
web_helper_failure_bin="$tmp/web-helper-failure-bin"
mkdir -p "$web_helper_failure_bin"
ln -s "$BASH" "$web_helper_failure_bin/bash"
cat >"$web_helper_failure_bin/firefox-open-tab" <<'EOF'
#!/usr/bin/env bash
printf '%q\n' "$@" >"$HELPER_LOG"
exit 1
EOF
cat >"$web_helper_failure_bin/firefox" <<'EOF'
#!/usr/bin/env bash
printf '%q\n' "$@" >"$WEB_LOG"
EOF
chmod +x "$web_helper_failure_bin/firefox-open-tab" "$web_helper_failure_bin/firefox"
web_helper_failure_log="$tmp/web-helper-failure.log"
web_helper_failure_firefox_log="$tmp/web-helper-failure-firefox.log"
HOME="$tmp/home" PATH="$web_helper_failure_bin:$bin" WINDOWS_TEST_RUNNING=true HELPER_LOG="$web_helper_failure_log" WEB_LOG="$web_helper_failure_firefox_log" "$helper" web
for _ in {1..10}; do
  [[ -f "$web_helper_failure_firefox_log" ]] && break
  sleep 0.1
done
[[ "$(<"$web_helper_failure_log")" == $'--new\nhttp://127.0.0.1:8006' ]]
[[ "$(<"$web_helper_failure_firefox_log")" == $'--new-tab\nhttp://127.0.0.1:8006' ]]



web_no_browser_bin="$tmp/web-no-browser-bin"
mkdir -p "$web_no_browser_bin"
ln -s "$BASH" "$web_no_browser_bin/bash"
web_no_browser_output=""
if web_no_browser_output="$(HOME="$tmp/home" PATH="$web_no_browser_bin:$bin" WINDOWS_TEST_RUNNING=true "$helper" web 2>&1)"; then
  false
fi
[[ "$web_no_browser_output" == *"Error: Firefox tab helper and Firefox are unavailable."* ]]

printf '%s\n' 'windows-rdp-client: ok'
