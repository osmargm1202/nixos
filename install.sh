#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${ORGMOS_REPO_URL:-github:osmargm1202/nixos}"
NIXOS_DIR="${ORGMOS_NIXOS_DIR:-/etc/nixos}"
DRY_RUN=false
PROMPT_INPUT=""
FLAKE_PATH="$NIXOS_DIR/flake.nix"
HARDWARE_PATH="$NIXOS_DIR/hardware-configuration.nix"

profiles=(hyprland gnome labwc sway i3)
gpus=(intel radeon nvidia nvidia-offload)
kernels=(zen lts)

say() {
  printf '%s\n' "$*"
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<EOF
Usage: install.sh [options]

Options:
  --dry-run             Print generated flake only; do not write or rebuild.
  --repo-url URL        Override ORGMOS flake input URL.
  --nixos-dir PATH      Override NixOS config directory.
  -h, --help            Show this help.

Examples:
  curl -fsSL https://nixos.or-gm.com/orgmos.sh | bash
  curl -fsSL https://nixos.or-gm.com/orgmos.sh | bash -s -- --dry-run
EOF
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      --repo-url)
        [ "$#" -ge 2 ] || fail "--repo-url requires a value"
        REPO_URL="$2"
        shift 2
        ;;
      --nixos-dir)
        [ "$#" -ge 2 ] || fail "--nixos-dir requires a value"
        NIXOS_DIR="$2"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        fail "unknown option: $1"
        ;;
    esac
  done

  FLAKE_PATH="$NIXOS_DIR/flake.nix"
  HARDWARE_PATH="$NIXOS_DIR/hardware-configuration.nix"
}

setup_prompt_input() {
  PROMPT_INPUT=""
  if [ ! -t 0 ] && [ -e /dev/tty ] && { : < /dev/tty; } 2>/dev/null; then
    PROMPT_INPUT="/dev/tty"
  fi
}

read_prompt() {
  local prompt="$1"
  local var_name="$2"

  if [ -n "$PROMPT_INPUT" ]; then
    read -r -p "$prompt" "$var_name" < "$PROMPT_INPUT"
  else
    read -r -p "$prompt" "$var_name"
  fi
}

confirm() {
  local prompt="$1"
  local answer=""
  read_prompt "$prompt [y/N]: " answer
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
    read_prompt "Profile [1-${#profiles[@]}] default 1 (${profiles[0]}): " choice
    choice="${choice:-1}"
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#profiles[@]}" ]; then
      SELECTED_PROFILE="${profiles[$((choice - 1))]}"
      return 0
    fi
    say "Invalid profile selection."
  done
}

choose_gpu() {
  say "Choose GPU profile:"
  say "  1) intel"
  say "  2) radeon"
  say "  3) nvidia"
  say "  4) nvidia-offload"

  local choice=""
  while true; do
    read_prompt "GPU [1-${#gpus[@]}] default 1 (${gpus[0]}): " choice
    choice="${choice:-1}"
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#gpus[@]}" ]; then
      SELECTED_GPU="${gpus[$((choice - 1))]}"
      case "$SELECTED_GPU" in
        intel) SELECTED_GPU_MODULE='orgmos.nixosModules.gpu.intel' ;;
        radeon) SELECTED_GPU_MODULE='orgmos.nixosModules.gpu.radeon' ;;
        nvidia) SELECTED_GPU_MODULE='orgmos.nixosModules.gpu.nvidia' ;;
        nvidia-offload) SELECTED_GPU_MODULE='orgmos.nixosModules.gpu."nvidia-offload"' ;;
      esac
      return 0
    fi
    say "Invalid GPU selection."
  done
}

choose_kernel() {
  say "Choose kernel profile:"
  say "  1) zen"
  say "  2) lts"
  say "  -) cachyos (pending; not available yet)"

  local choice=""
  while true; do
    read_prompt "Kernel [1-${#kernels[@]}] default 1 (${kernels[0]}): " choice
    choice="${choice:-1}"
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#kernels[@]}" ]; then
      SELECTED_KERNEL="${kernels[$((choice - 1))]}"
      case "$SELECTED_KERNEL" in
        zen) SELECTED_KERNEL_MODULE='orgmos.nixosModules.kernel.zen' ;;
        lts) SELECTED_KERNEL_MODULE='orgmos.nixosModules.kernel.lts' ;;
      esac
      return 0
    fi
    say "Invalid kernel selection. CachyOS is pending and cannot be selected yet."
  done
}

choose_hostname() {
  local current="orgmos"
  current="$(hostname 2>/dev/null || printf orgmos)"
  read_prompt "Hostname default ($current): " SELECTED_HOSTNAME
  SELECTED_HOSTNAME="${SELECTED_HOSTNAME:-$current}"

  if ! [[ "$SELECTED_HOSTNAME" =~ ^[a-zA-Z0-9-]+$ ]]; then
    fail "hostname may only contain letters, numbers, and hyphen"
  fi
}

pci_address_to_bus_id() {
  local address="$1"
  local compact="$address"
  local bus=""
  local slot_func=""
  local slot=""
  local func=""

  # Accept lspci forms like 00:02.0 and 0000:00:02.0.
  if [[ "$compact" == *:*:* ]]; then
    compact="${compact#*:}"
  fi

  bus="${compact%%:*}"
  slot_func="${compact#*:}"
  slot="${slot_func%%.*}"
  func="${slot_func##*.}"

  printf 'PCI:%d:%d:%d' "$((16#$bus))" "$((16#$slot))" "$((10#$func))"
}

valid_bus_id() {
  [[ "$1" =~ ^PCI:[0-9]+:[0-9]+:[0-9]+$ ]]
}

prompt_bus_id() {
  local label="$1"
  local detected="$2"
  local value=""

  while true; do
    if [ -n "$detected" ]; then
      read_prompt "$label Bus ID default ($detected): " value
      value="${value:-$detected}"
    else
      read_prompt "$label Bus ID (example PCI:0:2:0): " value
    fi

    if valid_bus_id "$value"; then
      printf '%s' "$value"
      return 0
    fi
    say "Invalid Bus ID. Expected format: PCI:<bus>:<slot>:<function>"
  done
}

detect_offload_bus_ids() {
  local pci_lines=""
  local intel_addr=""
  local nvidia_addr=""
  local detected_intel=""
  local detected_nvidia=""

  say "Detecting NVIDIA offload Bus IDs..."
  if command -v lspci >/dev/null 2>&1; then
    pci_lines="$(lspci -nn | grep -Ei 'VGA|3D|Display' || true)"
  else
    say "lspci not found. Install pciutils or enter Bus IDs manually."
  fi

  if [ -n "$pci_lines" ]; then
    say "Detected display devices:"
    say "$pci_lines"
    intel_addr="$(printf '%s\n' "$pci_lines" | awk 'BEGIN{IGNORECASE=1} /Intel/ {print $1; exit}')"
    nvidia_addr="$(printf '%s\n' "$pci_lines" | awk 'BEGIN{IGNORECASE=1} /NVIDIA/ {print $1; exit}')"

    if [ -n "$intel_addr" ]; then
      detected_intel="$(pci_address_to_bus_id "$intel_addr")"
    fi
    if [ -n "$nvidia_addr" ]; then
      detected_nvidia="$(pci_address_to_bus_id "$nvidia_addr")"
    fi
  fi

  if [ -n "$detected_intel" ]; then
    say "Detected Intel Bus ID:  $detected_intel"
  else
    say "Intel Bus ID not detected."
  fi

  if [ -n "$detected_nvidia" ]; then
    say "Detected NVIDIA Bus ID: $detected_nvidia"
  else
    say "NVIDIA Bus ID not detected."
  fi

  OFFLOAD_INTEL_BUS_ID="$(prompt_bus_id "Intel" "$detected_intel")"
  OFFLOAD_NVIDIA_BUS_ID="$(prompt_bus_id "NVIDIA" "$detected_nvidia")"
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

extra_modules_nix() {
  printf '        %s\n' "$SELECTED_GPU_MODULE"
  printf '        %s\n' "$SELECTED_KERNEL_MODULE"

  if [ "${SELECTED_GPU:-}" = "nvidia-offload" ]; then
    cat <<EOF
        {
          hardware.nvidia.prime = {
            intelBusId = "$OFFLOAD_INTEL_BUS_ID";
            nvidiaBusId = "$OFFLOAD_NVIDIA_BUS_ID";
          };
        }
EOF
  fi
}

write_flake() {
  local tmp
  local extra_modules
  tmp="$(mktemp)"
  extra_modules="$(extra_modules_nix)"

  cat > "$tmp" <<EOF
{
  inputs.orgmos.url = "$REPO_URL";

  outputs = { self, orgmos, ... }: {
    nixosConfigurations.default = orgmos.lib.mkGeneralHost {
      hardware = ./hardware-configuration.nix;
      profile = "$SELECTED_PROFILE";
      hostName = "$SELECTED_HOSTNAME";
      extraModules = [
$extra_modules
      ];
    };
  };
}
EOF

  say "Generated flake:"
  say "---"
  cat "$tmp"
  say "---"

  if [ "$DRY_RUN" = true ]; then
    say "Dry run: not writing $FLAKE_PATH."
    rm -f "$tmp"
    return 0
  fi

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
  parse_args "$@"
  setup_prompt_input

  say "ORGMOS installer"

  if [ "$DRY_RUN" = true ]; then
    say "Dry run: no files will be written and nixos-rebuild will not run."
  else
    require_nixos

    if [ ! -f "$HARDWARE_PATH" ]; then
      fail "missing $HARDWARE_PATH; run nixos-generate-config first"
    fi
  fi

  choose_profile
  choose_gpu
  choose_kernel
  choose_hostname

  if [ "$SELECTED_GPU" = "nvidia-offload" ]; then
    detect_offload_bus_ids
  fi

  say ""
  say "Install summary:"
  say "  Repository: $REPO_URL"
  say "  NixOS dir:  $NIXOS_DIR"
  say "  Hardware:   $HARDWARE_PATH"
  say "  Profile:    $SELECTED_PROFILE"
  say "  GPU:        $SELECTED_GPU"
  say "  Kernel:     $SELECTED_KERNEL"
  say "  Hostname:   $SELECTED_HOSTNAME"
  if [ "$SELECTED_GPU" = "nvidia-offload" ]; then
    say "  Intel Bus:  $OFFLOAD_INTEL_BUS_ID"
    say "  NVIDIA Bus: $OFFLOAD_NVIDIA_BUS_ID"
  fi
  say ""

  write_flake

  if [ "$DRY_RUN" = true ]; then
    say ""
    say "Dry run complete. To install, run without --dry-run:"
    say "  curl -fsSL https://nixos.or-gm.com/orgmos.sh | bash"
    return 0
  fi

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
