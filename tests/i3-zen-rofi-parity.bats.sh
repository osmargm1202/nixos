#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/dotfiles/config/profiles/i3/.local/bin"
CONFIG="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"
ROFI_DIR="$ROOT/dotfiles/config/profiles/i3/.config/rofi"
THEME="$ROFI_DIR/i3-menu.rasi"
MENU="$BIN/i3-main-menu"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

ZEN="$BIN/i3-zen-new-window"
grep -Fq 'i3-msg -t get_tree' "$ZEN" || fail 'Zen helper does not inspect current i3 windows'
grep -Fq -- '--new-tab about:blank' "$ZEN" || fail 'running Zen must receive a new blank tab'
grep -Fq 'i3-msg "[con_id=$con_id] focus"' "$ZEN" || fail 'Zen helper does not focus existing/new window'
grep -Fq '(.window_properties.class // "") == "app.zen_browser.zen"' "$ZEN" || fail 'Zen helper does not use exact Flatpak class'
grep -Fq '(.window_properties.class // "") == "zen-browser"' "$ZEN" || fail 'Zen helper does not use exact native class'
flatpak_line="$(grep -n 'flatpak info app.zen_browser.zen' "$ZEN" | head -n1 | cut -d: -f1)"
native_line="$(grep -n 'for browser in zen-browser zen' "$ZEN" | head -n1 | cut -d: -f1)"
[[ -n "$flatpak_line" && -n "$native_line" && "$flatpak_line" -lt "$native_line" ]] || fail 'Zen helper must preserve Hyprland Flatpak-first launch order'

[ -f "$THEME" ] || fail 'neutral i3 Rofi theme missing'
grep -Fq '@import "orgm-current.rasi"' "$THEME" || fail 'i3 Rofi theme does not use current palette'
grep -Fq 'theme="$HOME/.config/rofi/i3-menu.rasi"' "$BIN/i3-rofi" || fail 'i3-rofi does not force parity theme'
grep -Fq 'font: "JetBrainsMono Nerd Font 12"' "$BIN/i3-rofi" || fail 'i3-rofi font override differs from Hyprland'
grep -Fq 'element-icon { size: 32px; }' "$BIN/i3-rofi" || fail 'i3-rofi icon sizing differs from Hyprland'
grep -Fq 'listview { lines: 13; }' "$BIN/i3-rofi" || fail 'launcher/window/calc line count differs from Hyprland'
grep -Fq 'set $launcher $run i3-rofi --drun' "$CONFIG" || fail 'Mod+Space does not use themed Rofi launcher'
grep -Fq 'bindsym Mod1+Tab exec --no-startup-id $run i3-rofi --window' "$CONFIG" || fail 'Alt+Tab window selector is not themed'
grep -Fq 'Apps) exec i3-rofi --drun' "$MENU" || fail 'Apps menu bypasses themed Rofi'
grep -Fq 'Windows) exec i3-rofi --window' "$MENU" || fail 'Windows menu bypasses themed Rofi'

grep -Fq 'bindcode $mod+Mod1+65 exec --no-startup-id $run i3-main-menu' "$CONFIG" ||
  fail 'physical Win+Alt+Space system menu binding missing'
grep -Fq 'bindsym $mod+Mod1+space exec --no-startup-id $run i3-main-menu' "$CONFIG" ||
  fail 'symbolic Win+Alt+Space fallback binding missing'
grep -Fq 'bindsym $mod+F12 exec --no-startup-id $run i3-main-menu' "$CONFIG" ||
  fail 'system menu fallback binding missing'
if grep -Rqi 'hypr-menu' "$ROFI_DIR"; then
  fail 'i3 must use neutral theme naming, not hypr-menu'
fi

bash -n "$ZEN" "$BIN/i3-rofi"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
cat >"$tmp/tree.json" <<'JSON'
{
  "id": 1,
  "focus": [10],
  "nodes": [{
    "id": 10,
    "focus": [20],
    "nodes": [{
      "id": 20,
      "focus": [202, 101],
      "nodes": [
        {"id": 101, "focused": false, "focus": [], "nodes": [], "floating_nodes": [], "window_properties": {"class": "zen-browser"}},
        {"id": 202, "focused": false, "focus": [], "nodes": [], "floating_nodes": [], "window_properties": {"class": "app.zen_browser.zen"}}
      ],
      "floating_nodes": []
    }],
    "floating_nodes": []
  }],
  "floating_nodes": []
}
JSON
cat >"$tmp/bin/i3-msg" <<'STUB'
#!/usr/bin/env bash
if [[ "$*" == '-t get_tree' ]]; then cat "$ZEN_TREE"; else printf '%s\n' "$*" >>"$ZEN_FOCUS"; fi
STUB
cat >"$tmp/bin/flatpak" <<'STUB'
#!/usr/bin/env bash
if [[ "${1:-}" == info ]]; then exit 0; fi
printf '%s\n' "$*" >>"$ZEN_LAUNCH"
STUB
cat >"$tmp/bin/sleep" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
chmod +x "$tmp/bin/i3-msg" "$tmp/bin/flatpak" "$tmp/bin/sleep"
ZEN_TREE="$tmp/tree.json" ZEN_FOCUS="$tmp/focus" ZEN_LAUNCH="$tmp/launch" PATH="$tmp/bin:$PATH" "$ZEN"
grep -Fxq 'run app.zen_browser.zen --new-tab about:blank' "$tmp/launch" || fail 'running Flatpak Zen did not receive new tab'
grep -Fxq '[con_id=202] focus' "$tmp/focus" || fail 'helper did not focus most-recent Zen from i3 focus order'

printf 'PASS: i3 matches Zen and Rofi daily behavior without hypr-menu\n'
