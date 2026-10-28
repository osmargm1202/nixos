#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
cat > "$tmp/bin/xrandr" <<'STUB'
#!/usr/bin/env bash
printf 'Monitors: 1\n 0: +*eDP-1 %s/256x%s/144+0+0 eDP-1\n' "${TEST_WIDTH:-1366}" "${TEST_HEIGHT:-768}"
STUB
cat > "$tmp/bin/rofi" <<'STUB'
#!/usr/bin/env bash
printf '%s\0' "$@" > "$ROFI_ARGS"
STUB
chmod +x "$tmp/bin/"*
export PATH="$tmp/bin:$PATH" ROFI_ARGS="$tmp/args"
helper="$ROOT/dotfiles/config/profiles/i3-lightweight/.local/bin/i3-rofi"
for mode in --drun --window --calc --tab-picker; do
 "$helper" "$mode"
 python3 - "$ROFI_ARGS" "$mode" <<'PY'
import pathlib,sys
args=pathlib.Path(sys.argv[1]).read_bytes().decode().strip('\0').split('\0')
assert '-normal-window' not in args
assert args[args.index('-dpi')+1]=='96'
style=args[args.index('-theme-str')+1]
assert 'width: 480px' in style
assert f'lines: {6 if sys.argv[2]=="--calc" else 8};' in style
if sys.argv[2]=='--tab-picker':
 assert '-only-match' in args and '-no-custom' in args
 assert args[args.index('-format')+1]=='i'
PY
done
TEST_WIDTH=320 TEST_HEIGHT=480 "$helper" Help 20
python3 - "$ROFI_ARGS" <<'PY'
import pathlib,sys
args=pathlib.Path(sys.argv[1]).read_bytes().decode().split('\0')
style=args[args.index('-theme-str')+1]
assert 'width: 272px' in style and 'lines: 4;' in style
PY
# Third-party callers can supply both a CLI row count and their own theme.
python3 - "$ROOT" "$tmp" <<'PY'
import pathlib,sys
root,tmp=map(pathlib.Path,sys.argv[1:])
source=(root/'dotfiles/config/profiles/i3-lightweight/.local/bin/rofi').read_text()
(tmp/'rofi-wrapper').write_text(source.replace('/run/current-system/sw/bin/rofi',str(tmp/'bin/rofi')))
PY
for flag in -l -lines; do
  bash "$tmp/rofi-wrapper" -dmenu "$flag" 30 -normal-window \
    -theme-str 'window { width: 600px; } listview { lines: 30; }'
  python3 - "$ROFI_ARGS" "$flag" <<'PY'
import pathlib,sys
args=pathlib.Path(sys.argv[1]).read_bytes().decode().strip('\0').split('\0')
assert args[args.index(sys.argv[2])+1]=='8'
assert '-normal-window' not in args
styles=[args[i+1] for i,arg in enumerate(args) if arg=='-theme-str']
assert 'width: 480px' in styles[-1] and 'lines: 8;' in styles[-1]
PY
done
printf 'PASS: lightweight menus fit small displays and retain all modes and Firefox tab selection\n'
