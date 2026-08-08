#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER="$ROOT/dotfiles/config/shared/.local/bin/firefox-open-tab"
I3="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"
I3_WRAPPER="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-firefox-new-window"
I3_MENU="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-main-menu"
HYPR="$ROOT/dotfiles/config/profiles/hyprland/.config/hypr/lua/keybindings.lua"
HYPR_WRAPPER="$ROOT/dotfiles/config/profiles/hyprland/.local/bin/hypr-firefox-new-window"
HYPR_MENU="$ROOT/dotfiles/config/profiles/hyprland/.local/bin/hypr-apps-menu"
HYPR_SMART_RUN="$ROOT/dotfiles/config/profiles/hyprland/.local/bin/hypr-smart-run"
LABWC="$ROOT/dotfiles/config/profiles/labwc/.config/labwc/rc.xml"
MENU="$ROOT/dotfiles/config/profiles/labwc/.config/labwc/menu.xml"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

bash -n "$HELPER"
grep -Fq 'bindsym $mod+m exec --no-startup-id firefox-open-tab --new --prompt' "$I3" || fail 'i3 Win+M must create from the web prompt'
grep -Fq 'bindsym $mod+w exec --no-startup-id $browser' "$I3" || fail 'i3 Win+W binding missing'
grep -Fq 'exec firefox-open-tab --new "$@"' "$I3_WRAPPER" || fail 'i3 Win+W wrapper must create a tab'
grep -Fq 'Firefox) exec firefox-open-tab --focus' "$I3_MENU" || fail 'i3 Firefox menu must only focus'
grep -Fq 'mainMod .. " + M", hl.dsp.exec_cmd("firefox-open-tab --new --prompt")' "$HYPR" || fail 'Hyprland Win+M must create from the web prompt'
grep -Fq 'mainMod .. " + W", hl.dsp.exec_cmd("hypr-firefox-new-window")' "$HYPR" || fail 'Hyprland Win+W binding missing'
grep -Fq 'mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("firefox-open-tab --focus")' "$HYPR" || fail 'Hyprland Win+Shift+W must only focus'
grep -Fq 'exec firefox-open-tab --new "$@"' "$HYPR_WRAPPER" || fail 'Hyprland Win+W wrapper must create a tab'
grep -Fq "*'Firefox') exec firefox-open-tab --focus" "$HYPR_MENU" || fail 'Hyprland Firefox menu must only focus'
grep -Fq 'open_url() { nohup firefox-open-tab "$1" >/dev/null 2>&1 & }' "$HYPR_SMART_RUN" || fail 'Hyprland web launcher must only request existing Firefox tabs'
grep -Fq '<keybind key="W-w">' "$LABWC" || fail 'Labwc Win+W binding missing'
grep -Fq '<command>firefox-open-tab --new</command>' "$LABWC" || fail 'Labwc Win+W must create explicitly'
grep -Fq '<keybind key="W-m">' "$LABWC" || fail 'Labwc Win+M binding missing'
grep -Fq '<command>firefox-open-tab --new --prompt</command>' "$LABWC" || fail 'Labwc Win+M must create explicitly from the web prompt'
grep -Fq '<command>firefox-open-tab --focus</command>' "$MENU" || fail 'Labwc browser menu must only focus'

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
cat >"$tmp/bin/firefox" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$FIREFOX_ARGS"
EOF
cat >"$tmp/bin/windows-manager-linux-orgm-tab" <<'EOF'
#!/usr/bin/env bash
if [[ -n "${BRIDGE_ARGS:-}" ]]; then
  printf '%s\n' "$1" >"$BRIDGE_ARGS"
fi
[[ "${BRIDGE_OK:-0}" == 1 ]]
EOF
cat >"$tmp/bin/rofi" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$ROFI_RESULT"
EOF
cat >"$tmp/bin/notify-send" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$NOTIFY_ARGS"
EOF
cat >"$tmp/bin/i3-msg" <<'EOF'
#!/usr/bin/env bash
printf 'i3-msg %s\n' "$*" >>"$FOCUS_ARGS"
EOF
cat >"$tmp/bin/hyprctl" <<'EOF'
#!/usr/bin/env bash
printf 'hyprctl %s\n' "$*" >>"$FOCUS_ARGS"
EOF
cat >"$tmp/bin/wlrctl" <<'EOF'
#!/usr/bin/env bash
printf 'wlrctl %s\n' "$*" >>"$FOCUS_ARGS"
EOF
chmod +x "$tmp/bin"/*

wait_for_file() {
  local path="$1"
  for _ in {1..20}; do
    [[ -e "$path" ]] && return 0
    sleep 0.05
  done
  fail "timed out waiting for $path"
}

run_bridge_focus() {
  local desktop="$1" expected_focus="$2" input="$3" expected_url="$4"
  rm -f "$tmp/firefox-args" "$tmp/bridge-args" "$tmp/focus-args"
  BRIDGE_OK=1 BRIDGE_ARGS="$tmp/bridge-args" FIREFOX_ARGS="$tmp/firefox-args" \
    FOCUS_ARGS="$tmp/focus-args" XDG_CURRENT_DESKTOP="$desktop" PATH="$tmp/bin:$PATH" \
    "$HELPER" "$input"
  [[ "$(<"$tmp/bridge-args")" == "$expected_url" ]] || fail 'bridge did not receive the normalized URL'
  grep -Fxq "$expected_focus" "$tmp/focus-args" || fail "$desktop did not focus Firefox after bridge reuse"
  [[ ! -e "$tmp/firefox-args" ]] || fail 'focus-only URL mode must not create a Firefox tab'
}

run_explicit_new() {
  local input="$1" expected_url="$2"
  rm -f "$tmp/firefox-args" "$tmp/bridge-args"
  BRIDGE_ARGS="$tmp/bridge-args" FIREFOX_ARGS="$tmp/firefox-args" PATH="$tmp/bin:$PATH" \
    "$HELPER" --new "$input"
  wait_for_file "$tmp/firefox-args"
  [[ "$(<"$tmp/firefox-args")" == "--new-tab $expected_url" ]] || fail 'explicit creation did not normalize the URL'
  [[ ! -e "$tmp/bridge-args" ]] || fail 'explicit creation must not query the bridge'
}

run_bridge_focus i3 'i3-msg [class="(?i)firefox"] focus' pagina.net https://pagina.net
run_bridge_focus Hyprland 'hyprctl dispatch focuswindow class:^(firefox|Navigator)$' nas:8080 http://nas:8080

rm -f "$tmp/firefox-args" "$tmp/bridge-args" "$tmp/focus-args" "$tmp/notify-args"
if BRIDGE_OK=0 BRIDGE_ARGS="$tmp/bridge-args" FIREFOX_ARGS="$tmp/firefox-args" \
  FOCUS_ARGS="$tmp/focus-args" NOTIFY_ARGS="$tmp/notify-args" XDG_CURRENT_DESKTOP=i3 \
  PATH="$tmp/bin:$PATH" "$HELPER" pagina.net; then
  fail 'focus-only URL mode must fail when the bridge fails'
fi
[[ "$(<"$tmp/bridge-args")" == https://pagina.net ]] || fail 'failed bridge did not receive the normalized URL'
[[ ! -e "$tmp/firefox-args" ]] || fail 'failed bridge must never fall back to Firefox --new-tab'
wait_for_file "$tmp/notify-args"

run_explicit_new 10.0.0.13:8000 http://10.0.0.13:8000
rm -f "$tmp/firefox-args" "$tmp/bridge-args"
BRIDGE_ARGS="$tmp/bridge-args" FIREFOX_ARGS="$tmp/firefox-args" PATH="$tmp/bin:$PATH" \
  "$HELPER" --new
wait_for_file "$tmp/firefox-args"
[[ "$(<"$tmp/firefox-args")" == '--new-tab about:blank' ]] || fail 'URL-less creation did not open about:blank'
[[ ! -e "$tmp/bridge-args" ]] || fail 'URL-less creation must not query the bridge'


rm -f "$tmp/firefox-args" "$tmp/bridge-args"
ROFI_RESULT=pagina FIREFOX_ARGS="$tmp/firefox-args" BRIDGE_ARGS="$tmp/bridge-args" PATH="$tmp/bin:$PATH" \
  "$HELPER" --new --prompt
wait_for_file "$tmp/firefox-args"
[[ "$(<"$tmp/firefox-args")" == '--new-tab https://pagina.com' ]] || fail 'prompt creation did not normalize the selected URL'
[[ ! -e "$tmp/bridge-args" ]] || fail 'prompt creation must not query the bridge'

rm -f "$tmp/firefox-args" "$tmp/bridge-args" "$tmp/focus-args"
BRIDGE_ARGS="$tmp/bridge-args" FIREFOX_ARGS="$tmp/firefox-args" FOCUS_ARGS="$tmp/focus-args" \
  XDG_CURRENT_DESKTOP=labwc PATH="$tmp/bin:$PATH" "$HELPER" --focus
grep -Fxq 'wlrctl toplevel focus app_id:firefox' "$tmp/focus-args" || fail 'explicit focus mode did not focus Firefox'
[[ ! -e "$tmp/firefox-args" && ! -e "$tmp/bridge-args" ]] || fail 'explicit focus mode must not create or query a tab'

printf 'PASS: Firefox launcher creates only through explicit Win+M/Win+W routes\n'
