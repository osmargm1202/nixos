#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT/nixos/profiles/i3/i3.nix"
CONFIG="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"
HELPER="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-clipboard"
MENU_TEMPLATE="$ROOT/dotfiles/config/profiles/i3/.config/clipcat/clipcat-menu.toml"

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
printf '%s\n' "$*" >>"$CLIPCAT_SYSTEMCTL"
[[ "$*" != '--user is-active --quiet i3-clipcat.service' ]]
STUB
cat >"$tmp/bin/clipcat-menu" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$CLIPCAT_ARGS"
STUB
chmod +x "$tmp/bin/systemctl" "$tmp/bin/clipcat-menu"

CLIPCAT_SYSTEMCTL="$tmp/systemctl" CLIPCAT_ARGS="$tmp/args" HOME="$tmp/home" XDG_RUNTIME_DIR="$tmp/runtime" PATH="$tmp/bin:$PATH" "$HELPER"
grep -Fq -- "--rofi-extra-arguments=-theme,$tmp/home/.config/rofi/i3-menu.rasi,-theme-str," "$tmp/args" ||
  fail 'Clipcat must receive Rofi theme options as a single argument'
grep -Fq "server_endpoint = \"$tmp/runtime/clipcat/grpc.sock\"" "$tmp/runtime/clipcat-menu.toml" ||
  fail 'Clipcat menu must use the active runtime socket'

# Startup imports the active session before starting the watcher, with no menu.
rm "$tmp/args"
CLIPCAT_SYSTEMCTL="$tmp/startup" CLIPCAT_ARGS="$tmp/args" HOME="$tmp/home" XDG_RUNTIME_DIR="$tmp/runtime" DISPLAY=:fixture XAUTHORITY="$tmp/xauth" PATH="$tmp/bin:$PATH" "$HELPER" --start
[[ ! -e "$tmp/args" ]] || fail 'startup opened a clipboard menu'
printf '%s\n' '--user import-environment DISPLAY' '--user import-environment XAUTHORITY' '--user is-active --quiet i3-clipcat.service' '--user start i3-clipcat.service' >"$tmp/expected"
cmp "$tmp/expected" "$tmp/startup" || fail 'X11 environment must be imported before the daemon starts'
grep -Fq 'exec --no-startup-id $run i3-clipboard --start' "$CONFIG" || fail 'i3 startup bypasses the session-aware clipboard helper'
printf 'PASS: Win+V opens Clipcat history; session environment precedes daemon startup\n'
