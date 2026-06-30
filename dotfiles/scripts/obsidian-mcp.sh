#!/usr/bin/env bash
# Lanza Obsidian MCP con un vault por defecto.

set -euo pipefail

DISTROBOX_CONTAINER="arch"
DEFAULT_VAULT="${HOME}/Nextcloud/Documentos/obsidian-vault"
VAULT_PATH="${1:-${DEFAULT_VAULT}}"

if [[ "${VAULT_PATH}" == "~Nextcloud/"* ]]; then
  VAULT_PATH="${HOME}/Nextcloud/${VAULT_PATH#~Nextcloud/}"
fi

if [[ "${VAULT_PATH}" == "-h" || "${VAULT_PATH}" == "--help" ]]; then
  echo "Uso: $(basename "$0") [ruta_al_vault]"
  echo ""
  echo "Ejemplo: $(basename "$0") ~/Nextcloud/Documentos/obsidian-vault"
  exit 0
fi

if [[ ! -d "${VAULT_PATH}" ]]; then
  echo "Vault no encontrado: ${VAULT_PATH}" >&2
  exit 1
fi

exec distrobox-enter -- "${DISTROBOX_CONTAINER}" npx obsidian-mcp "${VAULT_PATH}"
