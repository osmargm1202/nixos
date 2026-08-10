#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-firefox-tabs"
ROFI="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-rofi"
I3="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"
DOTFILES="$ROOT/nixos/common-dotfiles.nix"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

bash -n "$HELPER"
bash -n "$ROFI"
grep -Fq 'bindsym $mod+Escape exec --no-startup-id i3-firefox-tabs' "$I3" || fail 'Win+Escape binding missing'
grep -Fq '".local/bin/i3-firefox-tabs"' "$DOTFILES" || fail 'tab selector is not deployed'
grep -Fq -- '--tab-picker)' "$ROFI" || fail 'i3-rofi tab-picker mode missing'
grep -Fq -- '-format i' "$ROFI" || fail 'tab-picker must return original row index'
grep -Fq -- '-no-custom -only-match' "$ROFI" || fail 'tab-picker must reject custom entries'

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
printf 'icon' >"$tmp/icon.png"
cat >"$tmp/bin/windows-manager-linux-orgm-tabs" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == list ]]; then
  printf '%s' "$TABS_JSON"
else
  printf '%s\n' "$*" >"$ACTIVATE_LOG"
fi
EOF
cat >"$tmp/bin/i3-rofi" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == --tab-picker ]] || exit 64
cat >"$ROFI_INPUT"
printf '1\n'
EOF
chmod +x "$tmp/bin/windows-manager-linux-orgm-tabs" "$tmp/bin/i3-rofi"
export TABS_JSON='[{"id":11,"windowId":1,"index":0,"active":true,"title":"Duplicado\n\u001f","url":"https://first.example/","iconPath":"'"$tmp"'/icon.png"},{"id":12,"windowId":2,"index":0,"active":false,"title":"Duplicado","url":"https://second.example/"}]'
ACTIVATE_LOG="$tmp/activate" ROFI_INPUT="$tmp/rofi-input" PATH="$tmp/bin:$PATH" "$HELPER"
[[ "$(<"$tmp/activate")" == 'activate 12' ]] || fail 'selected row did not activate the matching tab id'
python3 - "$tmp/rofi-input" <<'PY'
import sys
rows = open(sys.argv[1], 'rb').read().splitlines()
assert len(rows) == 2
assert b'\0icon\x1f' in rows[0] and b'/icon.png' in rows[0]
assert b'\0icon\x1ffirefox' in rows[1]
assert b'\n' not in rows[0].split(b'\0', 1)[0]
PY

printf 'PASS: i3 Firefox tab selector lists existing tabs and activates by index\n'
