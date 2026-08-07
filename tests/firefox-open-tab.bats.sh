#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER="$ROOT/dotfiles/config/shared/.local/bin/firefox-open-tab"
DOTFILES="$ROOT/nixos/common-dotfiles.nix"
I3="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"
HYPR="$ROOT/dotfiles/config/profiles/hyprland/.config/hypr/lua/keybindings.lua"
LABWC="$ROOT/dotfiles/config/profiles/labwc/.config/labwc/rc.xml"
MENU="$ROOT/dotfiles/config/profiles/labwc/.config/labwc/menu.xml"
LABWC_PROFILE="$ROOT/nixos/profiles/labwc.nix"
WEBAPPS="$ROOT/nixos/webapps.nix"
CATALOG="$ROOT/nixos/webapps.catalog.nix"
COMMON="$ROOT/nixos/common.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

bash -n "$HELPER"
grep -Fq '".local/bin/firefox-open-tab"' "$DOTFILES" || fail 'shared Firefox helper is not deployed'
grep -Fq 'bindsym $mod+m exec --no-startup-id firefox-open-tab --prompt' "$I3" || fail 'i3 Win+M must open the web prompt'
grep -Fq 'mainMod .. " + M", hl.dsp.exec_cmd("firefox-open-tab --prompt")' "$HYPR" || fail 'Hyprland Win+M must open the web prompt'
grep -Fq '<keybind key="W-m">' "$LABWC" || fail 'Labwc Win+M binding missing'
grep -Fq '<command>firefox-open-tab --prompt</command>' "$LABWC" || fail 'Labwc Win+M must open the web prompt'
grep -Fxq '    rofi' "$LABWC_PROFILE" || fail 'Labwc must install Rofi for Win+M'
grep -Fq '<command>firefox-open-tab</command>' "$MENU" || fail 'Labwc browser menu must use the shared helper'
grep -Fq './webapps.nix' "$COMMON" || fail 'webapp launchers are not imported'
grep -Fq 'firefox-open-tab' "$WEBAPPS" || fail 'webapp launchers must use Firefox helper'
[[ "$(grep -c 'url =' "$CATALOG")" == 26 ]] || fail 'webapp catalogue must retain all 26 launchers'
! grep -Fq -- '--app=' "$WEBAPPS" || fail 'webapps must not create separate browser apps'

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
cat >"$tmp/bin/firefox" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$FIREFOX_ARGS"
EOF
cat >"$tmp/bin/windows-manager-linux-orgm-tab" <<'EOF'
#!/usr/bin/env bash
if [[ "${BRIDGE_OK:-0}" == 1 ]]; then
  printf '%s\n' "$1" >"$BRIDGE_ARGS"
  exit 0
fi
exit 1
EOF
cat >"$tmp/bin/rofi" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$ROFI_RESULT"
EOF
chmod +x "$tmp/bin"/*

run_fallback() {
  local input="$1" expected="$2"
  rm -f "$tmp/firefox-args"
  FIREFOX_ARGS="$tmp/firefox-args" PATH="$tmp/bin:$PATH" "$HELPER" "$input"
  [[ "$(<"$tmp/firefox-args")" == "--new-tab $expected" ]] || fail "input $input normalized incorrectly"
}

run_fallback pagina https://pagina.com
run_fallback pagina.net https://pagina.net
run_fallback 10.0.0.13:8000 http://10.0.0.13:8000
run_fallback nas:8080 http://nas:8080
run_fallback https://example.com/path https://example.com/path
rm -f "$tmp/firefox-args"
BRIDGE_OK=1 BRIDGE_ARGS="$tmp/bridge-args" FIREFOX_ARGS="$tmp/firefox-args" PATH="$tmp/bin:$PATH" "$HELPER" pagina.net
[[ "$(<"$tmp/bridge-args")" == https://pagina.net ]] || fail 'bridge did not receive normalized URL'
[[ ! -e "$tmp/firefox-args" ]] || fail 'bridge success must not create a Firefox tab'
ROFI_RESULT=pagina.net FIREFOX_ARGS="$tmp/firefox-args" PATH="$tmp/bin:$PATH" "$HELPER" --prompt
[[ "$(<"$tmp/firefox-args")" == '--new-tab https://pagina.net' ]] || fail 'Rofi result was not normalized and opened'

printf 'PASS: shared Firefox launcher normalizes URLs and binds Win+M in every requested profile\n'
