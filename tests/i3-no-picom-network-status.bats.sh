#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT/nixos/profiles/i3.nix"
CONFIG="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"
STATUS_CONFIG="$ROOT/dotfiles/config/profiles/i3/.config/i3/i3status.conf"
WRAPPER="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3status-localized"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

! grep -qi 'picom' "$PROFILE" "$CONFIG" || fail 'i3 must not install or start Picom'
! grep -Fq 'order += "ipv6"' "$STATUS_CONFIG" || fail 'IPv6 block must be absent from i3status'
grep -Fq 'order += "wireless _first_"' "$STATUS_CONFIG" || fail 'Wi-Fi status block missing'
grep -Fq 'order += "ethernet _first_"' "$STATUS_CONFIG" || fail 'Ethernet status block missing'
grep -Fq 'NETWORK = "#7aa2f7"' "$WRAPPER" || fail 'network blocks must use subdued sky blue'
python3 - "$WRAPPER" <<'PY'
import importlib.machinery
import importlib.util
import sys

loader = importlib.machinery.SourceFileLoader("i3status_localized", sys.argv[1])
spec = importlib.util.spec_from_loader(loader.name, loader)
wrapper = importlib.util.module_from_spec(spec)
loader.exec_module(wrapper)
for name in ("wireless", "ethernet"):
    assert wrapper.localize({"name": name, "full_text": "connected"})["color"] == "#7aa2f7"
    assert wrapper.localize({"name": name, "full_text": "W: down", "color": "#ff0000"})["color"] == "#ff0000"
PY

printf 'PASS: i3 runs without Picom and uses subdued network status\n'
