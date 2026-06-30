#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/config/shared/.local/bin/hypr-usb-menu"
FIXTURE_DIR="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

USB_ROOT="$FIXTURE_DIR/sys/bus/usb/devices"
mkdir -p "$USB_ROOT"

usb_dev() {
  local bus="$1" vendor="$2" product="$3" manufacturer="$4" product_name="$5"
  mkdir -p "$USB_ROOT/$bus"
  printf '%s\n' "$vendor" > "$USB_ROOT/$bus/idVendor"
  printf '%s\n' "$product" > "$USB_ROOT/$bus/idProduct"
  printf '%s\n' "$manufacturer" > "$USB_ROOT/$bus/manufacturer"
  printf '%s\n' "$product_name" > "$USB_ROOT/$bus/product"
}

usb_dev '1-10' '174c' '2074' 'Asmedia' 'ASM107x'
usb_dev '1-11.1' '1b1c' '0a86' 'Corsair' 'Corsair HS55 SURROUND'
usb_dev '1-5' '1a2c' '9605' 'SEMICO' 'USB Gaming Keyboard'

ERR_FILE="$FIXTURE_DIR/stderr.log"
output="$(HYPR_USB_SYS_ROOT="$USB_ROOT" HYPR_SYS_ROOT="$FIXTURE_DIR/sys" "$SCRIPT" reconnect-headset --print 2>"$ERR_FILE")"
if [ -s "$ERR_FILE" ]; then
  cat "$ERR_FILE" >&2
fi

if grep -q '1-10\|1-5' <<<"$output"; then
  echo "Expected headset reconnect to exclude hub/keyboard, got:" >&2
  echo "$output" >&2
  exit 1
fi

grep -q 'unbind 1-11.1' <<<"$output"
grep -q 'bind 1-11.1' <<<"$output"
grep -q 'Corsair HS55 SURROUND' <<<"$output"
