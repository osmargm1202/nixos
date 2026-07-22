#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT/nixos/profiles/i3.nix"
CONFIG="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"
HELPER="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-clipboard"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

grep -Eq '^[[:space:]]+clipmenu[[:space:]]*$' "$PROFILE" || fail 'X11 clipmenu package missing'
grep -Fq 'exec --no-startup-id clipmenud' "$CONFIG" || fail 'clipboard history daemon missing'
grep -Fq 'export CM_LAUNCHER=rofi' "$HELPER" || fail 'clipboard selector is not Rofi'
grep -Fq 'clipmenu.6.$USER/line_cache' "$HELPER" || fail 'clipboard helper does not guard empty history'
grep -Fq 'No clipboard history yet' "$HELPER" || fail 'empty history has no useful feedback'
grep -Fq 'i3-menu.rasi' "$HELPER" || fail 'clipboard does not use i3 Rofi theme'
bash -n "$HELPER"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/runtime/clipmenu.6.testuser"
cat >"$tmp/bin/notify-send" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$CLIPBOARD_NOTIFY"
STUB
cat >"$tmp/bin/clipmenu" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$CLIPBOARD_CALLS"
STUB
chmod +x "$tmp/bin/notify-send" "$tmp/bin/clipmenu"
export CLIPBOARD_NOTIFY="$tmp/notify" CLIPBOARD_CALLS="$tmp/calls"
USER=testuser XDG_RUNTIME_DIR="$tmp/runtime" PATH="$tmp/bin:$PATH" "$HELPER"
grep -Fq 'No clipboard history yet' "$tmp/notify" || fail 'empty history did not notify'
[[ ! -e "$tmp/calls" ]] || fail 'empty history still launched broken clipmenu'
printf '1 copied text\n' >"$tmp/runtime/clipmenu.6.testuser/line_cache"
USER=testuser XDG_RUNTIME_DIR="$tmp/runtime" PATH="$tmp/bin:$PATH" "$HELPER"
grep -Fq -- '-theme' "$tmp/calls" || fail 'populated history did not launch themed Rofi clipmenu'

printf 'PASS: X11 clipboard history opens in themed Rofi with empty-state feedback\n'
