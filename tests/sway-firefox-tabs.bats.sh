#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER="$ROOT/dotfiles/config/profiles/sway/.local/bin/sway-firefox-tabs"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
bash -n "$HELPER"
grep -Fq 'bindsym $mod+Escape $exec sway-firefox-tabs' "$ROOT/dotfiles/config/profiles/sway/.config/sway/config" || fail 'Win+Esc binding missing'
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/runtime"
cat >"$tmp/bin/windows-manager-linux-orgm-tabs" <<'SH'
#!/usr/bin/env bash
if [[ "$1" == list ]]; then
  [[ "${BRIDGE_FAIL:-0}" == 0 ]] || exit 1
  printf '%s' "$TABS_JSON"
else
  printf '%s\n' "$*" >"$LOG/activate"
fi
SH
cat >"$tmp/bin/rofi" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$LOG/rofi-args"
cat >"$LOG/rows"
printf '%s\n' "${SELECTION:-1}"
exit "${ROFI_STATUS:-0}"
SH
cat >"$tmp/bin/sway-firefox-open-tab" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$LOG/focus"
SH
cat >"$tmp/bin/notify-send" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$LOG/notifications"
SH
chmod +x "$tmp/bin/"*
export LOG="$tmp" XDG_CURRENT_DESKTOP=sway XDG_RUNTIME_DIR="$tmp/runtime"
export HOME="$tmp/home" PATH="$tmp/bin:$PATH"
export TABS_JSON='[{"id":11,"title":"Duplicado\n\u001f","url":"https://first.example/"},{"id":42,"title":"Duplicado","url":"https://second.example/"}]'

"$HELPER"
[[ "$(<"$tmp/activate")" == 'activate 42' ]] || fail 'selected row must map to its original tab id'
[[ "$(<"$tmp/focus")" == '--focus-title Duplicado' ]] || fail 'must focus the chosen tab window without opening a new tab'
python3 - "$tmp/rows" "$tmp/rofi-args" <<'PY'
from pathlib import Path
import sys
rows=Path(sys.argv[1]).read_bytes().splitlines()
assert len(rows)==2 and b'\0icon\x1ffirefox' in rows[0]
assert b'\x1f' not in rows[0].split(b'\0',1)[0]
args=Path(sys.argv[2]).read_text().splitlines()
assert '-no-config' in args and '-only-match' in args
assert args[args.index('-format')+1]=='i'
assert args[args.index('-theme')+1].endswith('/.config/rofi-sway/sway-menu.rasi')
PY
rm "$tmp/activate" "$tmp/focus"
ROFI_STATUS=1 "$HELPER"
[[ ! -e "$tmp/activate" && ! -e "$tmp/focus" && ! -e "$tmp/notifications" ]] || fail 'Escape must cancel quietly without activation'
if ROFI_STATUS=2 "$HELPER"; then fail 'real picker failure must not succeed'; fi
[[ -s "$tmp/notifications" && ! -e "$tmp/activate" ]] || fail 'picker failure must notify, not activate'
rm "$tmp/notifications"
if SELECTION=999 "$HELPER"; then fail 'out-of-range selection must fail'; fi
[[ ! -e "$tmp/activate" ]] || fail 'invalid row must not activate any tab'
rm "$tmp/notifications" "$tmp/rows" "$tmp/rofi-args"
if BRIDGE_FAIL=1 "$HELPER"; then fail 'bridge failure must be reported'; fi
[[ ! -e "$tmp/rofi-args" && -s "$tmp/notifications" ]] || fail 'bridge failure must not open an empty picker'
rm "$tmp/notifications"
if TABS_JSON='not-json' "$HELPER" 2>"$tmp/formatter-error"; then fail 'malformed tab JSON must fail'; fi
[[ ! -e "$tmp/rofi-args" && -s "$tmp/notifications" ]] || fail 'formatter failure must not be treated as cancellation'
[[ -z "$(find "$tmp/runtime" -mindepth 1 -print -quit)" ]] || fail 'picker must clean up its temporary state'
# Exercise the real focus helper with multiple browser windows, not a focus stub.
cat >"$tmp/bin/swaymsg" <<'SH'
#!/usr/bin/env bash
if [[ "$*" == '-t get_tree' ]]; then
  printf '%s\n' "$SWAY_TREE"
else
  printf '%s\n' "$*" >"$LOG/window-focus"
fi
SH
chmod +x "$tmp/bin/swaymsg"
python3 - "$ROOT/dotfiles/config/profiles/sway/.local/bin/sway-firefox-open-tab" "$tmp" <<'PY'
import json, os, subprocess, sys
from pathlib import Path
helper, log = sys.argv[1], Path(sys.argv[2]) / 'window-focus'
first = {'id': 11, 'app_id': 'firefox', 'name': 'Other page — Mozilla Firefox', 'focused': True}
target = {'id': 22, 'app_id': 'firefox', 'name': 'Chosen page — Mozilla Firefox'}
cases = [
    ([first, target], 'Chosen page', 22),
    ([dict(first, name=target['name']), dict(target, urgent=True)], 'Chosen page', 22),
    ([dict(first, name=target['name'], focused=False), target], 'Chosen page', None),
    ([first, target], 'Missing page', None),
    ([first, dict(target, name='Unsafe "; kill; exec nope — Mozilla Firefox')], 'Unsafe "; kill; exec nope', 22),
    ([first, {'id': 33, 'window_properties': {'class': 'Firefox'}, 'name': 'X11 page - Mozilla Firefox'}], 'X11 page', 33),
]
for windows, title, expected in cases:
    log.unlink(missing_ok=True)
    env = dict(os.environ, SWAY_TREE=json.dumps({'nodes': windows}))
    result = subprocess.run([helper, '--focus-title', title], env=env, capture_output=True, text=True, timeout=5)
    assert result.returncode == (0 if expected else 1), (result.returncode, result.stderr)
    if expected:
        assert log.read_text().strip() == f'[con_id={expected}] focus'
    else:
        assert not log.exists(), 'ambiguous or missing title must not focus the first browser'
PY
printf 'PASS: Sway Firefox tab selection, multi-window focus, cancellation and failure handling\n'
