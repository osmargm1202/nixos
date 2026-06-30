#!/usr/bin/env bash

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/discord-window-shot.conf"
BIN_DIR="${HOME}/.local/bin"
DISTROBOX_CONTAINER="${DISCORD_SCREENSHOT_DISTROBOX:-arch}"
WEBHOOK_URL="${DISCORD_WEBHOOK_URL:-}"
MESSAGE="${DISCORD_SCREENSHOT_MESSAGE:-}"
TMP_FILE=""

usage() {
  cat <<EOF
Uso: $SCRIPT_NAME [install|configure|mensaje]

Hace un screenshot de la ventana actual y lo sube a Discord.

Captura:
  distrobox-enter $DISTROBOX_CONTAINER -- flameshot gui --accept-on-select --raw

Config:
  $SCRIPT_NAME configure
  export DISCORD_SCREENSHOT_DISTROBOX="arch"

Opcional:
  export DISCORD_SCREENSHOT_MESSAGE="Screenshot automatico"

Ejemplo:
  $SCRIPT_NAME "Bug visual en la ventana actual"

Comandos:
  install     Copia el script a $BIN_DIR/$SCRIPT_NAME
  configure   Pide el webhook y lo guarda en $CONFIG_FILE
EOF
}

cleanup() {
  if [[ -n "$TMP_FILE" && -f "$TMP_FILE" ]]; then
    rm -f "$TMP_FILE"
  fi
}

notify_msg() {
  local urgency="$1"
  local title="$2"
  local body="$3"

  if command -v notify-send >/dev/null 2>&1; then
    notify-send -u "$urgency" "$title" "$body"
  fi
}

install_script() {
  mkdir -p "$BIN_DIR"
  cp "$(realpath "$0")" "$BIN_DIR/$SCRIPT_NAME"
  chmod +x "$BIN_DIR/$SCRIPT_NAME"

  echo "Script instalado en $BIN_DIR/$SCRIPT_NAME"
  notify_msg normal "Discord Screenshot" "Script instalado en ~/.local/bin."
}

configure_script() {
  local webhook_url

  mkdir -p "$(dirname "$CONFIG_FILE")"

  printf 'Pega la URL del webhook de Discord: '
  IFS= read -r webhook_url

  if [[ -z "$webhook_url" ]]; then
    echo "Error: no ingresaste ninguna URL."
    notify_msg critical "Discord Screenshot" "No se guardo el webhook."
    exit 1
  fi

  cat >"$CONFIG_FILE" <<EOF
DISCORD_WEBHOOK_URL="$webhook_url"
EOF
  chmod 600 "$CONFIG_FILE"

  echo "Webhook guardado en $CONFIG_FILE"
  notify_msg normal "Discord Screenshot" "Webhook guardado correctamente."
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: falta el comando '$1'."
    exit 1
  fi
}

load_config() {
  if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
  fi

  DISTROBOX_CONTAINER="${DISCORD_SCREENSHOT_DISTROBOX:-${DISTROBOX_CONTAINER:-arch}}"
  WEBHOOK_URL="${DISCORD_WEBHOOK_URL:-${WEBHOOK_URL:-}}"

  if [[ $# -gt 0 ]]; then
    MESSAGE="$*"
  elif [[ -z "$MESSAGE" ]]; then
    MESSAGE="Screenshot $(date +'%Y-%m-%d %H:%M:%S')"
  fi
}

take_screenshot() {
  TMP_FILE="$(mktemp --suffix=.png)"

  if ! distrobox-enter "$DISTROBOX_CONTAINER" -- flameshot gui --accept-on-select --raw >"$TMP_FILE"; then
    echo "Error: no pude capturar con flameshot desde distrobox '$DISTROBOX_CONTAINER'."
    notify_msg critical "Discord Screenshot" "Fallo la captura con Flameshot."
    exit 1
  fi

  if [[ ! -s "$TMP_FILE" ]]; then
    echo "Error: el screenshot salio vacio."
    notify_msg critical "Discord Screenshot" "La captura salio vacia o fue cancelada."
    exit 1
  fi
}

send_to_discord() {
  local filename
  filename="window-$(date +'%Y%m%d-%H%M%S').png"

  if ! curl --fail --silent --show-error \
    -F "content=$MESSAGE" \
    -F "file1=@${TMP_FILE};type=image/png;filename=${filename}" \
    "$WEBHOOK_URL" >/dev/null; then
    notify_msg critical "Discord Screenshot" "No pude enviar la captura a Discord."
    exit 1
  fi
}

main() {
  trap cleanup EXIT

  case "${1:-}" in
  -h | --help)
    usage
    exit 0
    ;;
  install)
    install_script
    exit 0
    ;;
  configure)
    configure_script
    exit 0
    ;;
  esac

  require_cmd curl
  require_cmd distrobox-enter

  load_config "$@"

  if [[ -z "$WEBHOOK_URL" ]]; then
    echo "Error: define DISCORD_WEBHOOK_URL o guardalo en $CONFIG_FILE."
    notify_msg critical "Discord Screenshot" "Falta configurar el webhook de Discord."
    exit 1
  fi

  take_screenshot
  send_to_discord

  echo "Screenshot enviado a Discord."
  notify_msg normal "Discord Screenshot" "Captura enviada a Discord."
}

main "$@"
