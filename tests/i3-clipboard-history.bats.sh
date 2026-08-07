#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT/nixos/profiles/i3.nix"
CONFIG="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"
HELPER="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-clipboard"
MENU_TEMPLATE="$ROOT/dotfiles/config/shared/.config/clipcat/clipcat-menu.toml"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

grep -Fq 'description = "Clipcat clipboard history for i3";' "$PROFILE" ||
  fail 'i3 must run Clipcat as a persistent user service'
grep -Fq 'bindsym $mod+v exec --no-startup-id $run i3-clipboard' "$CONFIG" ||
  fail 'Win+V must launch the i3 clipboard helper'
grep -Fq 'clipcat-menu --config "$runtime_config" --finder rofi' "$HELPER" ||
  fail 'clipboard selector must use Clipcat with Rofi'
grep -Fq -- '--rofi-extra-arguments="-theme,$theme,-theme-str,$theme_override"' "$HELPER" ||
  fail 'Rofi arguments must be bound to Clipcat as one option value'
bash -n "$HELPER"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/home/.config/clipcat" "$tmp/home/.config/rofi" "$tmp/runtime"
cp "$MENU_TEMPLATE" "$tmp/home/.config/clipcat/clipcat-menu.toml"
cat >"$tmp/bin/systemctl" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
cat >"$tmp/bin/clipcat-menu" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$CLIPCAT_ARGS"
STUB
chmod +x "$tmp/bin/systemctl" "$tmp/bin/clipcat-menu"

CLIPCAT_ARGS="$tmp/args" HOME="$tmp/home" XDG_RUNTIME_DIR="$tmp/runtime" PATH="$tmp/bin:$PATH" "$HELPER"
grep -Fq -- "--rofi-extra-arguments=-theme,$tmp/home/.config/rofi/i3-menu.rasi,-theme-str," "$tmp/args" ||
  fail 'Clipcat must receive Rofi theme options as a single argument'
grep -Fq "server_endpoint = \"$tmp/runtime/clipcat/grpc.sock\"" "$tmp/runtime/clipcat-menu.toml" ||
  fail 'Clipcat menu must use the active runtime socket'

printf 'PASS: Win+V opens Clipcat history in themed Rofi\n'
