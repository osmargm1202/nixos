#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER="$ROOT/dotfiles/config/shared/.local/bin/firefox-open-tab"
FIREFOX_POLICY="$ROOT/nixos/firefox.nix"
I3="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"
I3_MENU="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-main-menu"
HYPR="$ROOT/dotfiles/config/profiles/hyprland/.config/hypr/lua/keybindings.lua"
HYPR_HELP="$ROOT/dotfiles/config/profiles/hyprland/.local/bin/hypr-keybindings-help"
HYPR_SMART_RUN="$ROOT/dotfiles/config/profiles/hyprland/.local/bin/hypr-smart-run"
LABWC="$ROOT/dotfiles/config/profiles/labwc/.config/labwc/rc.xml"
MENU="$ROOT/dotfiles/config/profiles/labwc/.config/labwc/menu.xml"
WEBAPPS="$ROOT/nixos/webapps.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

bash -n "$HELPER"
grep -Fq 'Homepage.StartPage = "previous-session";' "$FIREFOX_POLICY" || fail 'Firefox must restore the previous session on a cold launch'
grep -Fq 'home.file.".zen/native-messaging-hosts/windows_manager_linux_orgm.json".source' "$FIREFOX_POLICY" || fail 'Zen must receive the ORGM native messaging host manifest'
grep -Fq 'home.activation.installZenTabBridge' "$FIREFOX_POLICY" || fail 'Zen must install the signed ORGM tab bridge extension in its default profile'
grep -Fq 'bindsym $mod+m exec --no-startup-id firefox-open-tab --new-tab --prompt' "$I3" || fail 'i3 Win+M must open a new tab from the web prompt'
grep -Fq 'bindsym $mod+w exec --no-startup-id $browser' "$I3" || fail 'i3 Win+W binding missing'
grep -Fq 'set $browser $run firefox-open-tab --restore-or-focus' "$I3" || fail 'i3 Win+W must use restore-or-focus'
grep -Fq 'Firefox) exec firefox-open-tab --focus' "$I3_MENU" || fail 'i3 Firefox menu must only focus'
grep -Fq 'mainMod .. " + M", hl.dsp.exec_cmd("firefox-open-tab --new-tab --prompt")' "$HYPR" || fail 'Hyprland Win+M must open a new tab from the web prompt'
grep -Fq 'mainMod .. " + W", hl.dsp.exec_cmd("firefox-open-tab --restore-or-focus")' "$HYPR" || fail 'Hyprland Win+W must use restore-or-focus'
grep -Fq 'mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("firefox-open-tab --focus")' "$HYPR" || fail 'Hyprland Win+Shift+W must only focus'
grep -Fq "entry 'Win+W' 'Restaurar Firefox o abrir pestaña nueva' 'firefox-open-tab --restore-or-focus'" "$HYPR_HELP" || fail 'Hyprland Win+W help must describe session restoration or a new tab'
grep -Fq 'open_url() { nohup firefox-open-tab "$1" >/dev/null 2>&1 & }' "$HYPR_SMART_RUN" || fail 'Hyprland web launcher must reuse or create a Firefox tab'
grep -Fq '<keybind key="W-w">' "$LABWC" || fail 'Labwc Win+W binding missing'
grep -Fq '<command>firefox-open-tab --restore-or-focus</command>' "$LABWC" || fail 'Labwc Win+W must use restore-or-focus'
grep -Fq '<keybind key="W-m">' "$LABWC" || fail 'Labwc Win+M binding missing'
grep -Fq '<command>firefox-open-tab --new-tab --prompt</command>' "$LABWC" || fail 'Labwc Win+M must open a new tab from the web prompt'
grep -Fq '<command>firefox-open-tab --focus</command>' "$MENU" || fail 'Labwc browser menu must only focus'
grep -Fq 'exec = "/home/${userName}/.local/bin/firefox-open-tab ${app.url}";' "$WEBAPPS" || fail 'webapps must use the Firefox reuse-or-create helper'
[[ ! -e "$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-firefox-new-window" ]] || fail 'obsolete i3 Firefox wrapper remains'
[[ ! -e "$ROOT/dotfiles/config/profiles/hyprland/.local/bin/hypr-firefox-new-window" ]] || fail 'obsolete Hyprland Firefox wrapper remains'

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
cat >"$tmp/bin/firefox" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$#" >>"${FIREFOX_CALLS:?}"
printf '<%s>\n' "$*" >"${FIREFOX_ARGS:?}"
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
printf '%s\n' "$*" >>"${NOTIFY_ARGS:-/dev/null}"
EOF
cat >"$tmp/bin/ps" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${FIREFOX_PROCESS_STATUS:-}"
EOF
cat >"$tmp/bin/hyprctl" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == '-j clients' ]]; then
  printf '%s\n' "${HYPR_CLIENTS:-[]}"
  exit "${HYPR_QUERY_STATUS:-0}"
fi
printf 'hyprctl %s\n' "$*" >>"${FOCUS_ARGS:?}"
exit "${HYPR_DISPATCH_STATUS:-0}"
EOF
cat >"$tmp/bin/i3-msg" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == '-t get_tree' ]]; then
  if [[ -n "${I3_TREE:-}" ]]; then
    printf '%s\n' "$I3_TREE"
  else
    printf '{}\n'
  fi
  exit "${I3_QUERY_STATUS:-0}"
fi
printf 'i3-msg %s\n' "$*" >>"${FOCUS_ARGS:?}"
exit "${I3_DISPATCH_STATUS:-0}"
EOF
cat >"$tmp/bin/wlrctl" <<'EOF'
#!/usr/bin/env bash
printf 'wlrctl %s\n' "$*" >>"${FOCUS_ARGS:?}"
if [[ "$*" == 'toplevel find '* ]]; then
  exit "${WLR_FIND_STATUS:-0}"
fi
exit "${WLR_FOCUS_STATUS:-0}"
EOF
chmod +x "$tmp/bin"/*

wait_for_file() {
  local path="$1"
  for _ in {1..40}; do
    [[ -e "$path" ]] && return 0
    sleep 0.05
  done
  fail "timed out waiting for $path"
}

reset_logs() {
  rm -f "$tmp/firefox-args" "$tmp/firefox-calls" "$tmp/bridge-args" "$tmp/focus-args" "$tmp/notify-args"
}

hypr_single='[{"address":"0xhypr","class":"Firefox","focusHistoryID":3}]'
i3_single='{"id":1,"focus":[10],"nodes":[{"id":10,"focus":[101],"nodes":[{"id":101,"focus":[],"nodes":[],"floating_nodes":[],"window_properties":{"class":"Firefox"}}],"floating_nodes":[]}],"floating_nodes":[]}'

run_bridge_focus() {
  local desktop="$1" expected_focus="$2" input="$3" expected_url="$4"
  reset_logs
  BRIDGE_OK=1 BRIDGE_ARGS="$tmp/bridge-args" FIREFOX_ARGS="$tmp/firefox-args" FIREFOX_CALLS="$tmp/firefox-calls" \
    FOCUS_ARGS="$tmp/focus-args" HYPR_CLIENTS="$hypr_single" I3_TREE="$i3_single" \
    XDG_CURRENT_DESKTOP="$desktop" PATH="$tmp/bin:$PATH" "$HELPER" "$input"
  [[ "$(<"$tmp/bridge-args")" == "$expected_url" ]] || fail 'bridge did not receive the normalized URL'
  wait_for_file "$tmp/focus-args"
  grep -Fxq "$expected_focus" "$tmp/focus-args" || fail "$desktop did not focus Firefox after bridge reuse"
  [[ ! -e "$tmp/firefox-args" ]] || fail 'bridge reuse must not create a Firefox window'
}

run_explicit_new() {
  local input="$1" expected_url="$2"
  reset_logs
  FIREFOX_ARGS="$tmp/firefox-args" FIREFOX_CALLS="$tmp/firefox-calls" PATH="$tmp/bin:$PATH" "$HELPER" --new "$input"
  wait_for_file "$tmp/firefox-args"
  [[ "$(<"$tmp/firefox-args")" == "<--new-window $expected_url>" ]] || fail 'explicit creation did not normalize the URL'
  [[ ! -e "$tmp/bridge-args" ]] || fail 'explicit creation must not query the bridge'
}

run_explicit_tab() {
  local input="$1" expected_url="$2"
  reset_logs
  FIREFOX_ARGS="$tmp/firefox-args" FIREFOX_CALLS="$tmp/firefox-calls" PATH="$tmp/bin:$PATH" "$HELPER" --new-tab "$input"
  wait_for_file "$tmp/firefox-args"
  [[ "$(<"$tmp/firefox-args")" == "<--new-tab $expected_url>" ]] || fail 'explicit tab creation did not normalize the URL'
  [[ ! -e "$tmp/bridge-args" ]] || fail 'explicit tab creation must not query the bridge'
}

run_bridge_focus Hyprland 'hyprctl dispatch hl.dsp.focus({ window = "address:0xhypr" })' nas:8080 http://nas:8080
run_bridge_focus i3 'i3-msg [con_id=101] focus' pagina.net https://pagina.net
run_bridge_focus labwc 'wlrctl toplevel focus app_id:firefox app_id:org.mozilla.firefox' webapp.example https://webapp.example

reset_logs
BRIDGE_OK=0 BRIDGE_ARGS="$tmp/bridge-args" FIREFOX_ARGS="$tmp/firefox-args" FIREFOX_CALLS="$tmp/firefox-calls" \
  FOCUS_ARGS="$tmp/focus-args" I3_TREE="$i3_single" XDG_CURRENT_DESKTOP=i3 PATH="$tmp/bin:$PATH" "$HELPER" pagina.net
[[ "$(<"$tmp/bridge-args")" == https://pagina.net ]] || fail 'failed bridge did not receive the normalized URL'
wait_for_file "$tmp/firefox-args"
[[ "$(<"$tmp/firefox-args")" == '<--new-tab https://pagina.net>' ]] || fail 'failed bridge did not create a tab in Firefox'
wait_for_file "$tmp/focus-args"
grep -Fxq 'i3-msg [con_id=101] focus' "$tmp/focus-args" || fail 'fallback creation did not focus Firefox after opening its tab'

run_explicit_new 10.0.0.13:8000 http://10.0.0.13:8000
run_explicit_tab 10.0.0.13:8000 http://10.0.0.13:8000
reset_logs
FIREFOX_ARGS="$tmp/firefox-args" FIREFOX_CALLS="$tmp/firefox-calls" PATH="$tmp/bin:$PATH" "$HELPER" --new
wait_for_file "$tmp/firefox-args"
[[ "$(<"$tmp/firefox-args")" == '<--new-window about:blank>' ]] || fail 'URL-less creation did not open about:blank'
[[ ! -e "$tmp/bridge-args" ]] || fail 'URL-less creation must not query the bridge'
reset_logs
FIREFOX_ARGS="$tmp/firefox-args" FIREFOX_CALLS="$tmp/firefox-calls" PATH="$tmp/bin:$PATH" "$HELPER" --new-tab
wait_for_file "$tmp/firefox-args"
[[ "$(<"$tmp/firefox-args")" == '<--new-tab about:blank>' ]] || fail 'URL-less tab creation did not open about:blank'
[[ ! -e "$tmp/bridge-args" ]] || fail 'URL-less tab creation must not query the bridge'

reset_logs
ROFI_RESULT=pagina FIREFOX_ARGS="$tmp/firefox-args" FIREFOX_CALLS="$tmp/firefox-calls" PATH="$tmp/bin:$PATH" "$HELPER" --new-tab --prompt
wait_for_file "$tmp/firefox-args"
[[ "$(<"$tmp/firefox-args")" == '<--new-tab https://pagina.com>' ]] || fail 'prompt tab creation did not normalize the selected URL'
[[ ! -e "$tmp/bridge-args" ]] || fail 'prompt tab creation must not query the bridge'

reset_logs
FIREFOX_ARGS="$tmp/firefox-args" FIREFOX_CALLS="$tmp/firefox-calls" FOCUS_ARGS="$tmp/focus-args" \
  XDG_CURRENT_DESKTOP=labwc PATH="$tmp/bin:$PATH" "$HELPER" --focus
wait_for_file "$tmp/focus-args"
grep -Fxq 'wlrctl toplevel focus app_id:firefox app_id:org.mozilla.firefox' "$tmp/focus-args" || fail 'explicit focus mode did not focus Firefox'
[[ ! -e "$tmp/firefox-args" && ! -e "$tmp/bridge-args" ]] || fail 'explicit focus mode must not create or query a tab'

hypr_mru='[{"address":"0xolder","class":"Firefox","focusHistoryID":7},{"address":"0xrecent","initialClass":"Navigator","focusHistoryID":2},{"address":"0xunknown","class":"Firefox"}]'
reset_logs
FIREFOX_ARGS="$tmp/firefox-args" FIREFOX_CALLS="$tmp/firefox-calls" FOCUS_ARGS="$tmp/focus-args" \
  HYPR_CLIENTS="$hypr_mru" XDG_CURRENT_DESKTOP=Hyprland PATH="$tmp/bin:$PATH" "$HELPER" --restore-or-focus
grep -Fxq 'hyprctl dispatch hl.dsp.focus({ window = "address:0xrecent" })' "$tmp/focus-args" || fail 'Hyprland must focus the Firefox window with the lowest valid focusHistoryID'
wait_for_file "$tmp/firefox-args"
[[ "$(<"$tmp/firefox-args")" == '<--new-tab about:blank>' ]] || fail 'Hyprland focus must open a blank tab in the existing Firefox session'

i3_mru='{"id":1,"focus":[10,20],"nodes":[{"id":10,"focus":[101],"nodes":[{"id":101,"focus":[],"nodes":[],"floating_nodes":[],"window_properties":{"instance":"Navigator"}}],"floating_nodes":[]},{"id":20,"focus":[202],"nodes":[{"id":202,"focus":[],"nodes":[],"floating_nodes":[],"window_properties":{"class":"Firefox"}}],"floating_nodes":[]}],"floating_nodes":[]}'
reset_logs
FIREFOX_ARGS="$tmp/firefox-args" FIREFOX_CALLS="$tmp/firefox-calls" FOCUS_ARGS="$tmp/focus-args" \
  I3_TREE="$i3_mru" XDG_CURRENT_DESKTOP=i3 PATH="$tmp/bin:$PATH" "$HELPER" --restore-or-focus
grep -Fxq 'i3-msg [con_id=101] focus' "$tmp/focus-args" || fail 'i3 must focus the first Firefox leaf reached through focus ordering'
wait_for_file "$tmp/firefox-args"
[[ "$(<"$tmp/firefox-args")" == '<--new-tab about:blank>' ]] || fail 'i3 focus must open a blank tab in the existing Firefox session'

reset_logs
FIREFOX_ARGS="$tmp/firefox-args" FIREFOX_CALLS="$tmp/firefox-calls" FOCUS_ARGS="$tmp/focus-args" \
  XDG_CURRENT_DESKTOP=labwc PATH="$tmp/bin:$PATH" "$HELPER" --restore-or-focus
grep -Fxq 'wlrctl toplevel find app_id:firefox app_id:org.mozilla.firefox' "$tmp/focus-args" || fail 'Labwc must prove a Firefox window exists before focusing'
grep -Fxq 'wlrctl toplevel focus app_id:firefox app_id:org.mozilla.firefox' "$tmp/focus-args" || fail 'Labwc must focus an available Firefox window'
wait_for_file "$tmp/firefox-args"
[[ "$(<"$tmp/firefox-args")" == '<--new-tab about:blank>' ]] || fail 'Labwc focus must open a blank tab in the existing Firefox session'

run_restore_no_match() {
  local desktop="$1" hypr_clients="$2" i3_tree="$3" wlr_find_status="$4"
  reset_logs
  FIREFOX_ARGS="$tmp/firefox-args" FIREFOX_CALLS="$tmp/firefox-calls" FOCUS_ARGS="$tmp/focus-args" \
    HYPR_CLIENTS="$hypr_clients" I3_TREE="$i3_tree" WLR_FIND_STATUS="$wlr_find_status" \
    XDG_CURRENT_DESKTOP="$desktop" PATH="$tmp/bin:$PATH" "$HELPER" --restore-or-focus
  wait_for_file "$tmp/firefox-args"
  [[ "$(<"$tmp/firefox-args")" == '<>' ]] || fail "$desktop cold launch must pass no Firefox arguments"
  [[ "$(<"$tmp/firefox-calls")" == 0 ]] || fail "$desktop cold launch must invoke Firefox exactly once"
}

run_restore_no_match Hyprland '[]' '{}' 0
run_restore_no_match i3 '{}' '{}' 0
run_restore_no_match labwc '[]' '{}' 1

reset_logs
if FIREFOX_ARGS="$tmp/firefox-args" FIREFOX_CALLS="$tmp/firefox-calls" FOCUS_ARGS="$tmp/focus-args" NOTIFY_ARGS="$tmp/notify-args" \
  HYPR_QUERY_STATUS=2 FIREFOX_PROCESS_STATUS=Sl+ XDG_CURRENT_DESKTOP=Hyprland PATH="$tmp/bin:$PATH" "$HELPER" --restore-or-focus; then
  fail 'query failure with a running Firefox process must fail'
fi
[[ ! -e "$tmp/firefox-args" ]] || fail 'query failure with running Firefox must not launch another window'
grep -Fq 'already running' "$tmp/notify-args" || fail 'query failure with running Firefox must notify the user'

reset_logs
FIREFOX_ARGS="$tmp/firefox-args" FIREFOX_CALLS="$tmp/firefox-calls" FOCUS_ARGS="$tmp/focus-args" \
  HYPR_QUERY_STATUS=2 FIREFOX_PROCESS_STATUS=Z+ XDG_CURRENT_DESKTOP=Hyprland PATH="$tmp/bin:$PATH" "$HELPER" --restore-or-focus
wait_for_file "$tmp/firefox-args"
[[ "$(<"$tmp/firefox-args")" == '<>' ]] || fail 'a zombie Firefox process must not block session restoration'

for invalid in '--restore-or-focus --new' '--restore-or-focus --new-tab' '--restore-or-focus --prompt' '--restore-or-focus --focus' '--restore-or-focus example.com'; do
  reset_logs
  read -r -a args <<<"$invalid"
  if FIREFOX_ARGS="$tmp/firefox-args" FIREFOX_CALLS="$tmp/firefox-calls" FOCUS_ARGS="$tmp/focus-args" NOTIFY_ARGS="$tmp/notify-args" \
    PATH="$tmp/bin:$PATH" "$HELPER" "${args[@]}" >/dev/null 2>&1; then
    fail "invalid restore-or-focus combination succeeded: $invalid"
  else
    status=$?
  fi
  [[ "$status" == 2 ]] || fail "invalid restore-or-focus combination returned $status: $invalid"
  [[ ! -e "$tmp/firefox-args" && ! -e "$tmp/focus-args" ]] || fail "invalid restore-or-focus combination had side effects: $invalid"
done

printf 'PASS: Firefox launcher restores sessions or focuses existing windows\n'
