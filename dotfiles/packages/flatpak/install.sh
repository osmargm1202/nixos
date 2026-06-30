#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Uso: ./install.sh [--user|--system] [--file ruta]

Instala todos los paquetes listados en archivo de flatpaks.

Opciones:
  -u, --user      Instalar en usuario
  -s, --system    Instalar en sistema (requiere sudo)
  Sin opción: pregunta en terminal (u/s)
  -f, --file FILE Archivo de lista (default: pkg_flatpak.lst)
  -h, --help      Mostrar esta ayuda
EOF
}

TARGET=""
LIST_FILE="pkg_flatpak.lst"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -u|--user)
      TARGET="user"
      shift
      ;;
    -s|--system)
      TARGET="system"
      shift
      ;;
    -f|--file)
      shift
      if [[ $# -eq 0 ]]; then
        echo "Falta valor en --file" >&2
        exit 1
      fi
      LIST_FILE="$1"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Argumento inválido: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ ! -f "$LIST_FILE" ]]; then
  echo "No existe archivo: $LIST_FILE" >&2
  exit 1
fi

if ! command -v flatpak >/dev/null 2>&1; then
  echo "flatpak no está instalado." >&2
  exit 1
fi

if [[ -z "$TARGET" ]]; then
  if [[ -t 0 ]]; then
    while true; do
      read -r -p "Instalar en [u]ser o [s]ystem? [u/s]: " scope
      scope="${scope,,}"
      case "$scope" in
        u|user)
          TARGET="user"
          break
          ;;
        s|system)
          TARGET="system"
          break
          ;;
        *)
          echo "Respuesta inválida. Escriba u o s." >&2
          ;;
      esac
    done
  else
    echo "No se indicó --user/--system y no hay TTY interactivo." >&2
    echo "Usa --user o --system." >&2
    exit 1
  fi
fi

if [[ "$TARGET" == "system" ]]; then
  if ! command -v sudo >/dev/null 2>&1; then
    echo "Se requiere sudo para instalación system." >&2
    exit 1
  fi
fi

add_remote() {
  local scope="$1"
  local cmd_prefix=(flatpak)

  if [[ "$scope" == "system" ]]; then
    cmd_prefix=(sudo flatpak)
  fi

  "${cmd_prefix[@]}" remote-list --$scope --columns=name | awk '{print $1}' | grep -qx "flathub" || \
    "${cmd_prefix[@]}" remote-add --$scope --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
}

install_package() {
  local pkg="$1"
  local scope="$2"
  local cmd_prefix=(flatpak)

  if [[ "$scope" == "system" ]]; then
    cmd_prefix=(sudo flatpak)
  fi

  if [[ -z "$pkg" ]]; then
    return 0
  fi

  "${cmd_prefix[@]}" install --$scope -y --or-update "$pkg" >/dev/null
}

# Asegura repositorio flathub
add_remote "$TARGET"

echo "Instalando paquetes desde $LIST_FILE para --$TARGET"

failed=()
while IFS= read -r line || [[ -n "$line" ]]; do
  pkg="$(echo "$line" | tr -d '\r' | xargs)"

  [[ -z "$pkg" ]] && continue
  [[ "$pkg" == \#* ]] && continue


  if ! install_package "$pkg" "$TARGET"; then
    failed+=("$pkg")
    echo "Fallo: $pkg"
  else
    echo "OK: $pkg"
  fi
done < "$LIST_FILE"

if (( ${#failed[@]} > 0 )); then
  echo
  echo "Instalación incompleta. Fallos:"
  printf ' - %s\n' "${failed[@]}"
  exit 1
fi

echo "Todo instalado correctamente."