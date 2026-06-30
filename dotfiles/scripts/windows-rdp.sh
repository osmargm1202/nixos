#!/usr/bin/env bash

# ============================================================
# Windows RDP - Container Manager
# ============================================================

CONTAINER="windows"
DISTROBOX="arch"
RDP_HOST="localhost"
RDP_PORT="3389"
RDP_USER="osmarg"
RDP_PASS="hacker12"
WIDTH="2530"
HEIGHT="1301"

SCRIPT_NAME="windows-rdp"
BIN_DIR="$HOME/.local/bin"
APPS_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/icons"
ICON_URL="https://icones.pro/wp-content/uploads/2021/06/icone-windows-bleu.png"
ICON_FILE="$ICON_DIR/windows.png"

# Seconds to wait after port is open for RDP to fully initialize
RDP_BOOT_DELAY=10
# Max retries for RDP connection
RDP_MAX_RETRIES=5

# ============================================================
# Functions
# ============================================================

container_cmd() {
  if command -v docker &>/dev/null; then
    docker "$@" 2>/dev/null
  elif command -v podman &>/dev/null; then
    podman "$@" 2>/dev/null
  else
    echo "Error: Neither docker nor podman found."
    exit 1
  fi
}

is_installed() {
  [[ -x "$BIN_DIR/$SCRIPT_NAME" ]] && [[ -f "$APPS_DIR/$SCRIPT_NAME.desktop" ]]
}

notify_user() {
  local title="$1"
  local body="${2:-}"
  local icon="$ICON_FILE"

  # Sway/mako use the standard desktop notification protocol.
  # notify-send talks to mako, swaync, dunst, etc. when available.
  local is_sway=0
  local has_mako=0
  if [[ "${XDG_CURRENT_DESKTOP:-}" == *sway* ]] || [[ "${SWAYSOCK:-}" != "" ]]; then
    is_sway=1
  elif command -v swaymsg &>/dev/null && swaymsg -t get_version &>/dev/null; then
    is_sway=1
  fi
  if pgrep -x mako &>/dev/null; then
    has_mako=1
  elif command -v makoctl &>/dev/null && makoctl mode &>/dev/null; then
    has_mako=1
  fi

  if command -v notify-send &>/dev/null && { [[ $is_sway -eq 1 ]] || [[ $has_mako -eq 1 ]] || [[ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]]; }; then
    if [[ -f "$icon" ]]; then
      notify-send -a "$SCRIPT_NAME" -i "$icon" "$title" "$body" 2>/dev/null || true
    else
      notify-send -a "$SCRIPT_NAME" "$title" "$body" 2>/dev/null || true
    fi
  else
    echo "$title${body:+ $body}"
  fi
}

wait_rdp() {
  echo "Waiting for RDP on $RDP_HOST:$RDP_PORT..."
  for i in $(seq 1 60); do
    if nc -z "$RDP_HOST" "$RDP_PORT" 2>/dev/null; then
      echo "Port open. Waiting ${RDP_BOOT_DELAY}s for Windows to finish booting..."
      sleep "$RDP_BOOT_DELAY"
      echo "RDP is ready."
      return 0
    fi
    sleep 2
  done
  echo "Error: RDP did not become available after 120s."
  return 1
}

rdp_command() {
  local rdp_bin=""

  # Prefer native Wayland backend to get compositor clipboard access
  if [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v wlfreerdp &>/dev/null; then
    rdp_bin="wlfreerdp"
  elif command -v xfreerdp3 &>/dev/null; then
    rdp_bin="xfreerdp3"
  elif command -v xfreerdp &>/dev/null; then
    rdp_bin="xfreerdp"
  fi

  if [[ -n "$rdp_bin" ]]; then
    if command -v nvidia-offload &>/dev/null; then
      RDP_CMD=(nvidia-offload "$rdp_bin")
    elif command -v prime-run &>/dev/null; then
      RDP_CMD=(prime-run "$rdp_bin")
    else
      RDP_CMD=(/usr/bin/env __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia __VK_LAYER_NV_optimus=NVIDIA_only "$rdp_bin")
    fi
  else
    local fallback_bin="xfreerdp3"
    if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
      fallback_bin="wlfreerdp"
    fi
    if command -v nvidia-offload &>/dev/null; then
      RDP_CMD=(nvidia-offload distrobox-enter "$DISTROBOX" -- "$fallback_bin")
    elif command -v prime-run &>/dev/null; then
      RDP_CMD=(prime-run distrobox-enter "$DISTROBOX" -- "$fallback_bin")
    else
      RDP_CMD=(/usr/bin/env __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia __VK_LAYER_NV_optimus=NVIDIA_only distrobox-enter "$DISTROBOX" -- "$fallback_bin")
    fi
  fi
}

rdp_connect() {
  local started_container="${1:-0}"
  local attempt=1
  local max_retries=1
  local rc=1
  local -a RDP_CMD

  if [[ "$started_container" == "1" ]]; then
    max_retries="$RDP_MAX_RETRIES"
  fi

  rdp_command

  while [[ $attempt -le $max_retries ]]; do
    if [[ "$started_container" == "1" ]]; then
      echo "RDP connection attempt $attempt/$max_retries..."
    fi

    "${RDP_CMD[@]}" /v:"$RDP_HOST":"$RDP_PORT" \
      /u:"$RDP_USER" \
      /p:"$RDP_PASS" \
      /size:"${WIDTH}x${HEIGHT}" \
      /dynamic-resolution \
      /admin \
      /sec:nla:off \
      /tls:seclevel:0 \
      /network:lan \
      /bpp:32 \
      /audio-mode:0 \
      +clipboard \
      +home-drive \
      /cert:ignore \
      /wm-class:windows-rdp
    rc=$?

    # rc=0 means clean disconnect (user closed session)
    if [[ $rc -eq 0 ]]; then
      return 0
    fi

    # Startup path can race Windows RDP initialization; direct path should fail fast.
    if [[ "$started_container" == "1" && $attempt -lt $max_retries ]]; then
      echo "Connection failed (exit code $rc). Retrying in 5s..."
      sleep 5
    fi
    ((attempt++))
  done

  if [[ "$started_container" == "1" ]]; then
    echo "Error: Could not connect after $max_retries attempts."
    notify_user "Windows RDP error" "No se pudo conectar tras iniciar '$CONTAINER'."
  else
    echo "Error: RDP connection failed (exit code $rc)."
    notify_user "Windows RDP error" "La conexión directa falló (código $rc)."
  fi
  return 1
}

# ============================================================
# Commands
# ============================================================

do_start() {
  notify_user "Windows iniciando!" "Iniciando contenedor '$CONTAINER'."
  echo "Starting container '$CONTAINER'..."
  container_cmd start "$CONTAINER"
  echo "Container started."
}

do_stop() {
  echo "Stopping container '$CONTAINER'..."
  container_cmd stop "$CONTAINER"
  echo "Container stopped."
}

do_connect() {
  local started_container=0

  if ! nc -z "$RDP_HOST" "$RDP_PORT" 2>/dev/null; then
    started_container=1
    echo "RDP is not available. Starting container '$CONTAINER'..."
    do_start
    if ! wait_rdp; then
      notify_user "Windows RDP no disponible" "No se abrió $RDP_HOST:$RDP_PORT tras iniciar '$CONTAINER'."
      exit 1
    fi
  fi

  rdp_connect "$started_container"
}

do_run() {
  do_connect
}

do_install() {
  echo "Installing $SCRIPT_NAME..."

  # Copy script to bin
  mkdir -p "$BIN_DIR"
  cp "$(realpath "$0")" "$BIN_DIR/$SCRIPT_NAME"
  chmod +x "$BIN_DIR/$SCRIPT_NAME"
  echo "  Script  -> $BIN_DIR/$SCRIPT_NAME"

  # Download icon
  mkdir -p "$ICON_DIR"
  if command -v curl &>/dev/null; then
    curl -sL "$ICON_URL" -o "$ICON_FILE"
  elif command -v wget &>/dev/null; then
    wget -q "$ICON_URL" -O "$ICON_FILE"
  else
    echo "  Warning: curl/wget not found, skipping icon download."
  fi
  echo "  Icon    -> $ICON_FILE"

  # Create .desktop
  mkdir -p "$APPS_DIR"
  cat >"$APPS_DIR/$SCRIPT_NAME.desktop" <<EOF
[Desktop Entry]
Name=Windows VM
Comment=Launch Windows container via RDP
Exec=$BIN_DIR/$SCRIPT_NAME run
Icon=$ICON_FILE
Terminal=false
Type=Application
Categories=System;RemoteAccess;
Keywords=windows;rdp;vm;container;
StartupWMClass=windows-rdp
EOF
  chmod +x "$APPS_DIR/$SCRIPT_NAME.desktop"
  echo "  Desktop -> $APPS_DIR/$SCRIPT_NAME.desktop"

  echo "Install complete. '$SCRIPT_NAME' is now available."
}

# ============================================================
# Usage
# ============================================================

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME <command>

Commands:
  (none)     Install if first run, otherwise run
  run        Start container if needed and open RDP; leave container running on exit
  start      Start the Windows container only
  stop       Stop the Windows container only
  connect    Connect RDP; start container if needed
  install    Install script, icon and .desktop launcher

EOF
}

# ============================================================
# Main
# ============================================================

case "${1:-}" in
run) do_run ;;
start) do_start ;;
stop) do_stop ;;
connect) do_connect ;;
install) do_install ;;
-h | --help) usage ;;
"")
  if is_installed; then
    do_run
  else
    do_install
  fi
  ;;
*)
  echo "Unknown command: $1"
  usage
  exit 1
  ;;
esac
