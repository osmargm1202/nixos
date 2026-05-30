#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${ORGMOS_REPO_URL:-github:osmargm1202/nixos}"
NIXOS_DIR="${ORGMOS_NIXOS_DIR:-/etc/nixos}"
FLAKE_PATH="$NIXOS_DIR/flake.nix"
HARDWARE_PATH="$NIXOS_DIR/hardware-configuration.nix"

profiles=(hyprland gnome labwc sway i3)

say() {
  printf '%s\n' "$*"
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

confirm() {
  local prompt="$1"
  local answer=""
  read -r -p "$prompt [y/N]: " answer
  case "$answer" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

require_nixos() {
  if [ ! -e /etc/NIXOS ]; then
    fail "this installer must run on NixOS"
  fi
  if ! command -v nixos-rebuild >/dev/null 2>&1; then
    fail "nixos-rebuild not found; this installer must run on NixOS"
  fi
}

choose_profile() {
  say "Choose ORGMOS profile:"
  local i
  for i in "${!profiles[@]}"; do
    printf '  %d) %s\n' "$((i + 1))" "${profiles[$i]}"
  done

  local choice=""
  while true; do
    read -r -p "Profile [1-${#profiles[@]}] default 1 (${profiles[0]}): " choice
    choice="${choice:-1}"
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#profiles[@]}" ]; then
      SELECTED_PROFILE="${profiles[$((choice - 1))]}"
      return 0
    fi
    say "Invalid profile selection."
  done
}

choose_hostname() {
  local current="orgmos"
  current="$(hostname 2>/dev/null || printf orgmos)"
  read -r -p "Hostname default ($current): " SELECTED_HOSTNAME
  SELECTED_HOSTNAME="${SELECTED_HOSTNAME:-$current}"

  if ! [[ "$SELECTED_HOSTNAME" =~ ^[a-zA-Z0-9-]+$ ]]; then
    fail "hostname may only contain letters, numbers, and hyphen"
  fi
}

nixos_dir_command() {
  if [ -w "$NIXOS_DIR" ]; then
    "$@"
  else
    sudo "$@"
  fi
}

backup_existing_flake() {
  if [ -e "$FLAKE_PATH" ]; then
    local backup="$FLAKE_PATH.backup.$(date +%Y%m%d-%H%M%S)"
    say "Backing up existing flake: $backup"
    nixos_dir_command cp "$FLAKE_PATH" "$backup"
  fi
}

write_flake() {
  local tmp
  tmp="$(mktemp)"
  cat > "$tmp" <<EOF
{
  inputs.orgmos.url = "$REPO_URL";

  outputs = { self, orgmos, ... }: {
    nixosConfigurations.default = orgmos.lib.mkGeneralHost {
      hardware = ./hardware-configuration.nix;
      profile = "$SELECTED_PROFILE";
      hostName = "$SELECTED_HOSTNAME";
    };
  };
}
EOF

  say "Generated flake:"
  say "---"
  cat "$tmp"
  say "---"

  if confirm "Write this to $FLAKE_PATH?"; then
    backup_existing_flake
    nixos_dir_command install -m 0644 "$tmp" "$FLAKE_PATH"
  else
    rm -f "$tmp"
    fail "aborted before writing flake"
  fi
  rm -f "$tmp"
}

main() {
  say "ORGMOS installer"
  require_nixos

  if [ ! -f "$HARDWARE_PATH" ]; then
    fail "missing $HARDWARE_PATH; run nixos-generate-config first"
  fi

  choose_profile
  choose_hostname

  say ""
  say "Install summary:"
  say "  Repository: $REPO_URL"
  say "  NixOS dir:  $NIXOS_DIR"
  say "  Hardware:   $HARDWARE_PATH"
  say "  Profile:    $SELECTED_PROFILE"
  say "  Hostname:   $SELECTED_HOSTNAME"
  say ""

  write_flake

  say ""
  say "Next command: sudo nixos-rebuild switch --flake $NIXOS_DIR#default"
  if confirm "Run rebuild now?"; then
    sudo nixos-rebuild switch --flake "$NIXOS_DIR#default"
  else
    say "Skipped rebuild. Run manually when ready:"
    say "  sudo nixos-rebuild switch --flake $NIXOS_DIR#default"
  fi
}

main "$@"
