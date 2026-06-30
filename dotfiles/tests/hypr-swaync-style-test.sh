#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOTFILES="$ROOT/config/dotfiles.json"
WINDOWS="$ROOT/config/shared/.config/hypr/lua/windows-workspaces.lua"
SWAYNC_CONFIG="$ROOT/config/shared/.config/swaync/config.json"
SWAYNC="$ROOT/config/shared/.config/swaync/style.css"

python - "$DOTFILES" "$SWAYNC_CONFIG" <<'PY'
import json, sys
paths = json.load(open(sys.argv[1], encoding='utf-8'))['shared']['paths']
assert '.local/bin/hypr-focus-notification-app' in paths, 'hypr-focus-notification-app must be synced'
exec_cmd = json.load(open(sys.argv[2], encoding='utf-8'))['scripts']['focus-app-on-action']['exec']
assert '$HOME/.local/bin/hypr-focus-notification-app' in exec_cmd, 'SwayNC script exec must not depend on PATH'
PY

if grep 'title = "\^hardware-fastfetch\$"' "$WINDOWS" | grep -q 'float = true'; then
  echo 'hardware-fastfetch must not be forced floating' >&2
  exit 1
fi
if grep 'title = "\^hardware-fastfetch\$"' "$WINDOWS" | grep -Eq 'size =|center = true'; then
  echo 'hardware-fastfetch must not be forced to fixed floating size/center' >&2
  exit 1
fi
grep -q 'title = "\^hardware-fastfetch\$".*maximize = true' "$WINDOWS" || {
  echo 'hardware-fastfetch must be maximized' >&2
  exit 1
}

python - "$SWAYNC" <<'PY'
import re, sys
css = open(sys.argv[1], encoding='utf-8').read()
def block(selector):
    m = re.search(re.escape(selector) + r"\s*\{([^}]*)\}", css, re.S)
    if not m:
        raise SystemExit(f'missing selector {selector}')
    return m.group(1)
outer = block('.notification-background')
inner = block('.notification')
content = block('.notification-content')
assert 'border:' in outer and '@panel_border' in outer, 'outer notification background keeps single border'
assert 'border:' not in inner or 'border: none' in inner, 'inner notification must not have visible border'
assert 'background:' not in inner or 'transparent' in inner, 'inner notification must not draw card background'
assert 'border:' not in content or 'border: none' in content, 'notification content must not have visible border'
assert 'background:' not in content or 'transparent' in content, 'notification content must be transparent'
PY
