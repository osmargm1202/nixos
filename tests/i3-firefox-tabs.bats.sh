#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER="$ROOT/dotfiles/config/shared/.local/bin/firefox-tabs"
I3_HELPER="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-firefox-tabs"
I3_ROFI="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-rofi"
I3="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"
HYPR="$ROOT/dotfiles/config/profiles/hyprland/.config/hypr/lua/keybindings.lua"
LABWC="$ROOT/dotfiles/config/profiles/labwc/.config/labwc/rc.xml"
DOTFILES="$ROOT/nixos/common-dotfiles.nix"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

bash -n "$HELPER"
bash -n "$I3_HELPER"
bash -n "$I3_ROFI"
grep -Fq 'bindsym $mod+Escape exec --no-startup-id i3-firefox-tabs' "$I3" || fail 'i3 Win+Escape binding missing'
grep -Fq 'exec firefox-tabs "$@"' "$I3_HELPER" || fail 'i3 tab selector must use the shared picker'
grep -Fq 'mainMod .. " + Escape", hl.dsp.exec_cmd("firefox-tabs")' "$HYPR" || fail 'Hyprland Win+Escape binding missing'
grep -Fq "entry 'Win+Esc' 'Pestañas Firefox' 'firefox-tabs'" "$ROOT/dotfiles/config/profiles/hyprland/.local/bin/hypr-keybindings-help" || fail 'Hyprland shortcut help is stale'
grep -Fq '<keybind key="W-Escape">' "$LABWC" || fail 'Labwc Win+Escape binding missing'
grep -Fq '<command>firefox-tabs</command>' "$LABWC" || fail 'Labwc Win+Escape must launch the tab picker'
grep -Fq '".local/bin/firefox-tabs"' "$DOTFILES" || fail 'shared tab selector is not deployed'
grep -Fq -- '--tab-picker)' "$I3_ROFI" || fail 'i3-rofi tab-picker mode missing'
grep -Fq -- '-format i' "$I3_ROFI" || fail 'tab-picker must return original row index'
grep -Fq -- '-no-custom -only-match' "$I3_ROFI" || fail 'tab-picker must reject custom entries'

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
cat >"$tmp/bin/rofi" <<'EOF'
#!/usr/bin/env bash
case " $* " in
  *" -format i "*)
    cat >"$ROFI_INPUT"
    printf '1\n'
    ;;
  *) exit 64 ;;
esac
EOF
cat >"$tmp/bin/fuzzel" <<'EOF'
#!/usr/bin/env bash
cat >"$FUZZEL_INPUT"
sed -n '2p' "$FUZZEL_INPUT"
EOF
cat >"$tmp/bin/firefox-open-tab" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$FIREFOX_FOCUS_LOG"
EOF
chmod +x "$tmp/bin/windows-manager-linux-orgm-tabs" "$tmp/bin/i3-rofi" "$tmp/bin/rofi" "$tmp/bin/fuzzel" "$tmp/bin/firefox-open-tab"
export TABS_JSON='[{"id":11,"windowId":1,"index":0,"active":true,"title":"Duplicado\n\u001f","url":"https://first.example/","iconPath":"'"$tmp"'/icon.png"},{"id":12,"windowId":2,"index":0,"active":false,"title":"Duplicado","url":"https://second.example/"}]'

run_picker() {
  local desktop="$1" runner="$2"
  rm -f "$tmp/activate" "$tmp/firefox-focus" "$tmp/rofi-input" "$tmp/fuzzel-input"
  ACTIVATE_LOG="$tmp/activate" FIREFOX_FOCUS_LOG="$tmp/firefox-focus" ROFI_INPUT="$tmp/rofi-input" FUZZEL_INPUT="$tmp/fuzzel-input" \
    XDG_CURRENT_DESKTOP="$desktop" PATH="$tmp/bin:$ROOT/dotfiles/config/shared/.local/bin:$PATH" "$runner"
  [[ "$(<"$tmp/activate")" == 'activate 12' ]] || fail "$desktop selected the wrong tab"
  [[ "$(<"$tmp/firefox-focus")" == '--focus' ]] || fail "$desktop did not request Firefox compositor focus"
}

run_picker i3 "$I3_HELPER"
python3 - "$tmp/rofi-input" <<'PY'
import sys
rows = open(sys.argv[1], 'rb').read().splitlines()
assert len(rows) == 2
assert b'\0icon\x1f' in rows[0] and b'/icon.png' in rows[0]
assert b'\0icon\x1ffirefox' in rows[1]
assert b'\n' not in rows[0].split(b'\0', 1)[0]
PY
run_picker Hyprland "$HELPER"
run_picker labwc "$HELPER"
grep -Fq '[12] Duplicado — second.example' "$tmp/fuzzel-input" || fail 'Labwc picker must preserve the selected tab id'

printf 'PASS: Firefox tab picker works in i3, Hyprland, and Labwc\n'
