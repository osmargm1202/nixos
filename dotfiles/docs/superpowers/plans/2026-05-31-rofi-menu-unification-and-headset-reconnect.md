# Rofi Menu Unification and Headset Reconnect Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every Hyprland menu/helper use Rofi with host-specific sizing variables, remove active Fuzzel usage, and add a Waybar Bluetooth headset reconnect chooser.

**Architecture:** Add one shared shell library, `hypr-rofi-lib`, that owns theme/env loading and Rofi invocation. Migrate existing menus and helper launchers to source that library. Add `hypr-bluetooth-reconnect` plus Waybar module/style entries.

**Tech Stack:** Bash/sh scripts, Rofi, Hyprland Lua config, Waybar JSONC-style config, bluetoothctl, Fish fallback for `unbindheadset`, orgm-dot sync workflow.

---

## File map

- Create `config/shared/.local/bin/hypr-rofi-lib` — shared Rofi sizing/theme/env functions.
- Create `config/shared/.local/bin/hypr-rofi-calc` — Rofi calculator prompt.
- Create `config/shared/.local/bin/hypr-rofi-window` — Rofi Hyprland window switcher.
- Create `config/shared/.local/bin/hypr-rofi-open-file` — Rofi file opener.
- Create `config/shared/.local/bin/hypr-rofi-open-file-dir` — Rofi directory opener.
- Create `config/shared/.local/bin/hypr-rofi-open-file-terminal` — Rofi terminal-in-directory opener.
- Create `config/shared/.local/bin/hypr-rofi-ssh-host` — Rofi SSH host chooser.
- Create `config/shared/.local/bin/hypr-rofi-tmux-arch` — Rofi tmux session chooser.
- Create `config/shared/.local/bin/hypr-bluetooth-reconnect` — Bluetooth disconnect/wait/connect chooser.
- Modify `config/shared/.local/bin/hypr-main-menu` — source shared lib, remove local sizing block, route Apps via shared drun.
- Modify `config/shared/.local/bin/hypr-tools-menu` — source shared lib and route Search files to Rofi helper.
- Modify `config/shared/.local/bin/hypr-performance-menu`, `hypr-system-menu`, `hypr-wifi-menu`, `hypr-bluetooth-menu`, `hypr-keyboard-menu`, `hypr-theme-chooser` — source shared lib and use consistent dmenu.
- Modify `config/shared/.local/bin/hypr-power-menu` — use shared sizing with power-specific overrides.
- Modify `config/shared/.local/bin/hypr-keybindings-help` and `hypr-keyhelper` — update labels/commands away from Fuzzel.
- Modify `config/shared/.config/hypr/lua/programs.lua` and `keybindings.lua` — point active keybindings to Rofi helpers.
- Modify `config/shared/.config/waybar-hypr/config` and `style.css` — add headset reconnect button.
- Modify `config/dotfiles.json` — add new scripts if script paths are explicit in managed path lists.

---

## Task 1: Add shared Rofi library

**Files:**
- Create: `config/shared/.local/bin/hypr-rofi-lib`

- [ ] **Step 1: Create library**

Write `config/shared/.local/bin/hypr-rofi-lib`:

```bash
#!/usr/bin/env bash
# Shared Rofi helpers for Hyprland menus. Source this file; do not execute it.

hypr_rofi_load_env() {
  HYPR_ROFI_THEME="${HYPR_ROFI_THEME:-$HOME/.config/rofi/hypr-menu.rasi}"
  HYPR_ROFI_ENV="${HYPR_ROFI_ENV:-$HOME/.config/rofi/hypr-menu.env}"

  if [ -f "$HYPR_ROFI_ENV" ]; then
    # shellcheck disable=SC1090
    . "$HYPR_ROFI_ENV"
  fi

  HYPR_ROFI_SCALE="${HYPR_ROFI_SCALE:-1.00}"
  HYPR_ROFI_WIDTH="${HYPR_ROFI_WIDTH:-$(awk -v s="$HYPR_ROFI_SCALE" 'BEGIN { printf "%dpx", 600 * s }')}"
  HYPR_ROFI_LINES="${HYPR_ROFI_LINES:-$(awk -v s="$HYPR_ROFI_SCALE" 'BEGIN { printf "%d", 13 * s }')}"
  HYPR_ROFI_FONT_SIZE="${HYPR_ROFI_FONT_SIZE:-$(awk -v s="$HYPR_ROFI_SCALE" 'BEGIN { printf "%d", 12 * s }')}"
  HYPR_ROFI_ICON_SIZE="${HYPR_ROFI_ICON_SIZE:-$(awk -v s="$HYPR_ROFI_SCALE" 'BEGIN { printf "%dpx", 32 * s }')}"
  HYPR_ROFI_ELEMENT_PADDING="${HYPR_ROFI_ELEMENT_PADDING:-$(awk -v s="$HYPR_ROFI_SCALE" 'BEGIN { printf "%dpx", 8 * s }')}"
}

hypr_rofi_need() {
  if ! command -v rofi >/dev/null 2>&1; then
    notify-send "Rofi" "rofi no está instalado." 2>/dev/null || true
    return 1
  fi
}

hypr_rofi_theme_str() {
  local lines="${1:-$HYPR_ROFI_LINES}"
  local width="${2:-$HYPR_ROFI_WIDTH}"
  printf 'configuration { font: "JetBrainsMono Nerd Font %s"; } window { width: %s; } listview { lines: %s; } element { padding: %s; } element-icon { size: %s; }' \
    "$HYPR_ROFI_FONT_SIZE" "$width" "$lines" "$HYPR_ROFI_ELEMENT_PADDING" "$HYPR_ROFI_ICON_SIZE"
}

hypr_rofi_dmenu() {
  local prompt="$1"
  local lines="${2:-$HYPR_ROFI_LINES}"
  local width="${3:-$HYPR_ROFI_WIDTH}"
  shift || true
  hypr_rofi_need || return 1
  rofi -dmenu -i -show-icons -p "$prompt" -theme "$HYPR_ROFI_THEME" -theme-str "$(hypr_rofi_theme_str "$lines" "$width")"
}

hypr_rofi_markup_dmenu() {
  local prompt="$1"
  local lines="${2:-$HYPR_ROFI_LINES}"
  local width="${3:-$HYPR_ROFI_WIDTH}"
  hypr_rofi_need || return 1
  rofi -dmenu -i -markup-rows -p "$prompt" -theme "$HYPR_ROFI_THEME" -theme-str "$(hypr_rofi_theme_str "$lines" "$width")"
}

hypr_rofi_drun() {
  hypr_rofi_need || return 1
  rofi -show drun -theme "$HYPR_ROFI_THEME" -theme-str "$(hypr_rofi_theme_str)"
}

hypr_rofi_load_env
```

- [ ] **Step 2: Mark executable**

Run:

```bash
chmod +x config/shared/.local/bin/hypr-rofi-lib
bash -n config/shared/.local/bin/hypr-rofi-lib
```

Expected: no output, exit 0.

- [ ] **Step 3: Commit**

```bash
git add config/shared/.local/bin/hypr-rofi-lib
git commit -m "feat: add shared Hyprland rofi helper"
```

---

## Task 2: Migrate current Rofi menus to shared library

**Files:**
- Modify: `config/shared/.local/bin/hypr-main-menu`
- Modify: `config/shared/.local/bin/hypr-tools-menu`
- Modify: `config/shared/.local/bin/hypr-performance-menu`
- Modify: `config/shared/.local/bin/hypr-system-menu`
- Modify: `config/shared/.local/bin/hypr-wifi-menu`
- Modify: `config/shared/.local/bin/hypr-bluetooth-menu`
- Modify: `config/shared/.local/bin/hypr-keyboard-menu`
- Modify: `config/shared/.local/bin/hypr-power-menu`
- Modify: `config/shared/.local/bin/hypr-theme-chooser`

- [ ] **Step 1: Update each script header**

For each script, load the common library after `set -euo pipefail`:

```bash
lib="${HYPR_ROFI_LIB:-$HOME/.local/bin/hypr-rofi-lib}"
# shellcheck disable=SC1090
. "$lib"
```

Remove duplicated `theme=...`, `env_file=...`, `scale=...`, `width=...`, `lines=...`, `font_size=...`, `icon_size=...`, and local `pick()` blocks unless they add unique behavior.

- [ ] **Step 2: Replace direct Rofi dmenu calls**

Use this pattern:

```bash
choice="$(printf '%s\n' 'Item 1' 'Item 2' '󰅖 Cancel' | hypr_rofi_dmenu 'Prompt' || true)"
```

For `hypr-main-menu`, use:

```bash
choice="$(printf '%s\n' \
  '󰀻 Apps' \
  '󰒓 Tools' \
  '󱐋 Performance' \
  '󰖩 WiFi' \
  '󰂯 Bluetooth' \
  '󰍉 Search' \
  '󰌌 Keybinds' \
  '󰔎 Theme' \
  '󰒓 System' \
  '󰑓 Reload Dock' \
  '󰐥 Power' \
  '󰌌 Keyboard' \
  '󰣆 Web App Maker' \
  '󰅖 Quit' | hypr_rofi_dmenu 'Hyprland' || true)"
```

For Apps case:

```bash
*'Apps') exec hypr_rofi_drun ;;
```

For `hypr-power-menu`, preserve compact width using:

```bash
power_width="${HYPR_ROFI_POWER_WIDTH:-$(awk -v s="$HYPR_ROFI_SCALE" 'BEGIN { printf "%dpx", 360 * s }')}"
choice="$(printf '%s\n' '󰌾 Lock' '󰤄 Suspend' '󰒲 Hibernate' '󰗼 Logout' '󰜉 Reboot' '󰐥 Power off' '󰅖 Cancel' | hypr_rofi_dmenu 'Power' 7 "$power_width" || true)"
```

- [ ] **Step 3: Static check**

Run:

```bash
bash -n config/shared/.local/bin/hypr-main-menu \
  config/shared/.local/bin/hypr-tools-menu \
  config/shared/.local/bin/hypr-performance-menu \
  config/shared/.local/bin/hypr-system-menu \
  config/shared/.local/bin/hypr-wifi-menu \
  config/shared/.local/bin/hypr-bluetooth-menu \
  config/shared/.local/bin/hypr-keyboard-menu \
  config/shared/.local/bin/hypr-power-menu \
  config/shared/.local/bin/hypr-theme-chooser
```

Expected: no output, exit 0.

- [ ] **Step 4: Host sizing check**

Run:

```bash
distrobox-host-exec orgm-dot sync
distrobox-host-exec sh -lc 'HYPR_ROFI_ENV=$HOME/.config/rofi/hypr-menu.env bash -x ~/.local/bin/hypr-main-menu </dev/null >/tmp/hypr-main-menu.out 2>/tmp/hypr-main-menu.x || true; grep -E "HYPR_ROFI_SCALE|width|JetBrainsMono" /tmp/hypr-main-menu.x | head'
```

Expected: debug output includes `HYPR_ROFI_SCALE=1.25` and scaled width/font.

- [ ] **Step 5: Commit**

```bash
git add config/shared/.local/bin/hypr-main-menu config/shared/.local/bin/hypr-tools-menu config/shared/.local/bin/hypr-performance-menu config/shared/.local/bin/hypr-system-menu config/shared/.local/bin/hypr-wifi-menu config/shared/.local/bin/hypr-bluetooth-menu config/shared/.local/bin/hypr-keyboard-menu config/shared/.local/bin/hypr-power-menu config/shared/.local/bin/hypr-theme-chooser
git commit -m "refactor: use shared rofi sizing for menus"
```

---

## Task 3: Add Rofi replacements for Fuzzel helpers

**Files:**
- Create: `config/shared/.local/bin/hypr-rofi-calc`
- Create: `config/shared/.local/bin/hypr-rofi-window`
- Create: `config/shared/.local/bin/hypr-rofi-open-file`
- Create: `config/shared/.local/bin/hypr-rofi-open-file-dir`
- Create: `config/shared/.local/bin/hypr-rofi-open-file-terminal`
- Create: `config/shared/.local/bin/hypr-rofi-ssh-host`
- Create: `config/shared/.local/bin/hypr-rofi-tmux-arch`

- [ ] **Step 1: Create helpers**

Use this exact shared header in all Bash helpers:

```bash
#!/usr/bin/env bash
set -euo pipefail
lib="${HYPR_ROFI_LIB:-$HOME/.local/bin/hypr-rofi-lib}"
# shellcheck disable=SC1090
. "$lib"
```

Create `hypr-rofi-calc`:

```bash
#!/usr/bin/env bash
set -euo pipefail
lib="${HYPR_ROFI_LIB:-$HOME/.local/bin/hypr-rofi-lib}"
# shellcheck disable=SC1090
. "$lib"

expr="$(printf '' | hypr_rofi_dmenu 'Calc' 3 || true)"
[ -n "${expr:-}" ] || exit 0

if command -v qalc >/dev/null 2>&1; then
  result="$(qalc -t "$expr" 2>/dev/null | tail -n 1 || true)"
else
  result="$(awk "BEGIN { print ($expr) }" 2>/dev/null || true)"
fi

[ -n "${result:-}" ] || exit 1
printf '%s' "$result" | wl-copy
notify-send "Calc" "$expr = $result" 2>/dev/null || true
```

Create `hypr-rofi-window`:

```bash
#!/usr/bin/env bash
set -euo pipefail
lib="${HYPR_ROFI_LIB:-$HOME/.local/bin/hypr-rofi-lib}"
# shellcheck disable=SC1090
. "$lib"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
clients="$(hyprctl clients -j 2>/dev/null || true)"

if command -v jq >/dev/null 2>&1 && [ -n "$clients" ]; then
  printf '%s' "$clients" | jq -r '.[] | "\(.address)\t[\(.workspace.name)] \(.class) — \(.title)"' > "$tmp"
else
  hyprctl clients 2>/dev/null | awk '
    /^Window / { if (addr != "") print addr "\t[" ws "] " class " — " title; addr="0x" $2; class=""; title=""; ws="" }
    /^[[:space:]]*class:/ { class=$2 }
    /^[[:space:]]*title:/ { sub(/^[[:space:]]*title:[[:space:]]*/, ""); title=$0 }
    /^[[:space:]]*workspace:/ { ws=$3 }
    END { if (addr != "") print addr "\t[" ws "] " class " — " title }
  ' > "$tmp"
fi

selection="$(cut -f2- "$tmp" | hypr_rofi_dmenu 'Window' "${HYPR_ROFI_WINDOW_LINES:-14}" "${HYPR_ROFI_WINDOW_WIDTH:-$HYPR_ROFI_WIDTH}" || true)"
[ -n "${selection:-}" ] || exit 0
addr="$(awk -F'\t' -v label="$selection" '$2 == label { print $1; exit }' "$tmp")"
[ -n "${addr:-}" ] || exit 1
hyprctl dispatch "hl.dsp.focus({ window = \"address:$addr\" })"
```

Create file helpers by reusing this body and changing final action:

```bash
#!/usr/bin/env bash
set -euo pipefail
lib="${HYPR_ROFI_LIB:-$HOME/.local/bin/hypr-rofi-lib}"
# shellcheck disable=SC1090
. "$lib"

cd "$HOME"
selection="$({
  find . -type f \
    -not -path '*/.*/*' \
    -not -path './.*' \
    -not -path './go/*' \
    -not -path './paru/*' \
    -not -path '*/node_modules/*' \
    -not -path '*/target/*' \
    -printf '%T@\t%P\n' 2>/dev/null \
    | sort -rn \
    | cut -f2-
} | hypr_rofi_dmenu 'File' "${HYPR_ROFI_FILE_LINES:-18}" "${HYPR_ROFI_FILE_WIDTH:-$HYPR_ROFI_WIDTH}" || true)"

[ -n "${selection:-}" ] || exit 0
xdg-open "$HOME/$selection"
```

For `hypr-rofi-open-file-dir`, use prompt `Dir` and final action:

```bash
dir="$(dirname "$HOME/$selection")"
exec nautilus "$dir"
```

For `hypr-rofi-open-file-terminal`, use prompt `Term dir` and final action:

```bash
dir="$(dirname "$HOME/$selection")"
exec kitty --directory "$dir"
```

Create `hypr-rofi-ssh-host`:

```bash
#!/usr/bin/env bash
set -euo pipefail
lib="${HYPR_ROFI_LIB:-$HOME/.local/bin/hypr-rofi-lib}"
# shellcheck disable=SC1090
. "$lib"

hosts=""
if [ -f "$HOME/.ssh/config" ]; then
  hosts="$(awk 'tolower($1) == "host" { for (i = 2; i <= NF; i++) if ($i !~ /[*?]/) print $i }' "$HOME/.ssh/config" 2>/dev/null || true)"
fi
known_hosts="$(awk -F'[ ,]' '{print $1}' "$HOME/.ssh/known_hosts" 2>/dev/null | grep -v '^|' | grep -v '^$' | sed 's/^\[//; s/\].*$//' || true)"
hosts="$(printf '%s\n%s\n' "$hosts" "$known_hosts" | sort -u | sed '/^$/d')"
selection="$(printf '%s\n' "$hosts" | hypr_rofi_dmenu 'SSH' "${HYPR_ROFI_SSH_LINES:-14}" "${HYPR_ROFI_SSH_WIDTH:-$HYPR_ROFI_WIDTH}" || true)"
[ -n "${selection:-}" ] || exit 0
exec kitty -e ssh "$selection"
```

Create `hypr-rofi-tmux-arch`:

```bash
#!/usr/bin/env bash
set -euo pipefail
lib="${HYPR_ROFI_LIB:-$HOME/.local/bin/hypr-rofi-lib}"
# shellcheck disable=SC1090
. "$lib"

selection="$(distrobox-enter arch -- tmux ls 2>/dev/null | hypr_rofi_dmenu 'tmux' "${HYPR_ROFI_TMUX_LINES:-10}" || true)"
[ -n "${selection:-}" ] || exit 0
session="${selection%%:*}"
exec kitty -e distrobox-enter arch -- tmux attach -t "$session"
```

- [ ] **Step 2: Static check and executable bits**

```bash
chmod +x config/shared/.local/bin/hypr-rofi-*
bash -n config/shared/.local/bin/hypr-rofi-calc config/shared/.local/bin/hypr-rofi-window config/shared/.local/bin/hypr-rofi-open-file config/shared/.local/bin/hypr-rofi-open-file-dir config/shared/.local/bin/hypr-rofi-open-file-terminal config/shared/.local/bin/hypr-rofi-ssh-host config/shared/.local/bin/hypr-rofi-tmux-arch
```

Expected: no output, exit 0.

- [ ] **Step 3: Commit**

```bash
git add config/shared/.local/bin/hypr-rofi-*
git commit -m "feat: add rofi replacements for fuzzel helpers"
```

---

## Task 4: Rewire keybindings, menus, and help away from Fuzzel

**Files:**
- Modify: `config/shared/.config/hypr/lua/programs.lua`
- Modify: `config/shared/.config/hypr/lua/keybindings.lua`
- Modify: `config/shared/.local/bin/hypr-tools-menu`
- Modify: `config/shared/.local/bin/hypr-keybindings-help`
- Modify: `config/shared/.local/bin/hypr-keyhelper`

- [ ] **Step 1: Update active program/keybinding refs**

Expected replacements:

```text
hypr-fuzzel -> hypr-main-menu or rofi -show drun through hypr-main-menu Apps
fuzzel-open-file -> hypr-rofi-open-file
fuzzel-open-file-dir -> hypr-rofi-open-file-dir
fuzzel-open-file-terminal -> hypr-rofi-open-file-terminal
fuzzel-hypr-window -> hypr-rofi-window
fuzzel-tmux-arch -> hypr-rofi-tmux-arch
fuzzel-calc -> hypr-rofi-calc
fuzzel-ssh-host -> hypr-rofi-ssh-host
cliphist + fuzzel -> cliphist + rofi
```

In `programs.lua`, set menu program to `hypr-main-menu` or a Rofi launcher wrapper, not `hypr-fuzzel`.

In `keybindings.lua`, replace helper commands:

```lua
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("hypr-rofi-open-file"))
hl.bind(mainMod .. " + CTRL + M", hl.dsp.exec_cmd("hypr-rofi-open-file-dir"))
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd("hypr-rofi-open-file-terminal"))
hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd("hypr-rofi-window"))
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd("hypr-rofi-tmux-arch"))
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("hypr-rofi-calc"))
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("hypr-rofi-ssh-host"))
```

- [ ] **Step 2: Update menus/help text**

In `hypr-tools-menu`, route Search files:

```bash
*'Search files') exec ~/.local/bin/hypr-rofi-open-file ;;
```

In `hypr-keybindings-help` and `hypr-keyhelper`, use the new command names and replace visible `fuzzel` text with `rofi`.

- [ ] **Step 3: Verify no active Fuzzel refs**

Run:

```bash
rg -n "fuzzel|hypr-fuzzel" config/shared/.local/bin config/shared/.config/hypr config/shared/.config/waybar-hypr
```

Expected: no active refs. If old compatibility scripts remain under `.local/bin/fuzzel-*`, either remove them or ignore only those file names after confirming no script calls them.

- [ ] **Step 4: Commit**

```bash
git add config/shared/.config/hypr/lua/programs.lua config/shared/.config/hypr/lua/keybindings.lua config/shared/.local/bin/hypr-tools-menu config/shared/.local/bin/hypr-keybindings-help config/shared/.local/bin/hypr-keyhelper
git commit -m "refactor: route Hyprland helpers through rofi"
```

---

## Task 5: Add Bluetooth reconnect chooser and Waybar button

**Files:**
- Create: `config/shared/.local/bin/hypr-bluetooth-reconnect`
- Modify: `config/shared/.config/waybar-hypr/config`
- Modify: `config/shared/.config/waybar-hypr/style.css`

- [ ] **Step 1: Create reconnect script**

Write `config/shared/.local/bin/hypr-bluetooth-reconnect`:

```bash
#!/usr/bin/env bash
set -euo pipefail
lib="${HYPR_ROFI_LIB:-$HOME/.local/bin/hypr-rofi-lib}"
# shellcheck disable=SC1090
. "$lib"

notify() {
  notify-send "Bluetooth reconnect" "$1" 2>/dev/null || true
}

if ! command -v bluetoothctl >/dev/null 2>&1; then
  notify "bluetoothctl no está instalado."
  exit 1
fi

list="$(bluetoothctl devices 2>/dev/null || true)"
if [ -z "$list" ]; then
  notify "No hay dispositivos Bluetooth conocidos."
  exit 0
fi

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
printf '%s\n' "$list" | awk '/^Device / { mac=$2; $1=""; $2=""; sub(/^  */, ""); print mac "\t" $0 }' > "$tmp"

selection="$(awk -F'\t' '{ print $2 "  " $1 }' "$tmp" | hypr_rofi_dmenu 'Reconnect BT' "${HYPR_ROFI_BT_LINES:-12}" || true)"
[ -n "${selection:-}" ] || exit 0
mac="$(printf '%s\n' "$selection" | awk '{ print $NF }')"
[ -n "$mac" ] || exit 1

if command -v fish >/dev/null 2>&1 && fish -lc 'type -q unbindheadset' >/dev/null 2>&1; then
  if fish -lc "unbindheadset '$mac'"; then
    notify "Reconectado con unbindheadset: $mac"
    exit 0
  fi
fi

bluetoothctl disconnect "$mac" >/tmp/hypr-bt-reconnect.log 2>&1 || true
sleep 2
if bluetoothctl connect "$mac" >>/tmp/hypr-bt-reconnect.log 2>&1; then
  notify "Reconectado: $mac"
else
  notify "Falló reconexión: $mac"
  exit 1
fi
```

- [ ] **Step 2: Make executable and static check**

```bash
chmod +x config/shared/.local/bin/hypr-bluetooth-reconnect
bash -n config/shared/.local/bin/hypr-bluetooth-reconnect
```

Expected: no output, exit 0.

- [ ] **Step 3: Add Waybar module**

In `config/shared/.config/waybar-hypr/config`, add `custom/headset_reconnect` near existing right modules, next to `bluetooth`:

```json
"custom/headset_reconnect": {
  "format": "󰋋",
  "tooltip": true,
  "tooltip-format": "Reconnect Bluetooth device",
  "on-click": "hypr-bluetooth-reconnect"
}
```

Add module name in the right modules array near `bluetooth`:

```json
"custom/headset_reconnect",
"bluetooth",
```

- [ ] **Step 4: Add Waybar style**

In `config/shared/.config/waybar-hypr/style.css`, include `#custom-headset_reconnect` in the same selector groups as `#bluetooth` and add a color rule:

```css
#custom-headset_reconnect { color: @blue; }
```

- [ ] **Step 5: Commit**

```bash
git add config/shared/.local/bin/hypr-bluetooth-reconnect config/shared/.config/waybar-hypr/config config/shared/.config/waybar-hypr/style.css
git commit -m "feat: add bluetooth reconnect rofi button"
```

---

## Task 6: Dotfiles registration, cleanup, and verification

**Files:**
- Modify: `config/dotfiles.json` if needed.
- Delete or leave unreferenced compatibility scripts after checking user preference:
  - `config/shared/.local/bin/fuzzel-calc`
  - `config/shared/.local/bin/fuzzel-hypr-window`
  - `config/shared/.local/bin/fuzzel-open-file`
  - `config/shared/.local/bin/fuzzel-open-file-dir`
  - `config/shared/.local/bin/fuzzel-open-file-terminal`
  - `config/shared/.local/bin/fuzzel-ssh-host`
  - `config/shared/.local/bin/fuzzel-tmux-arch`
  - `config/shared/.local/bin/hypr-fuzzel`

- [ ] **Step 1: Register new scripts**

Check if `.local/bin` is managed as a directory or individual paths:

```bash
jq '.shared.paths, .hosts.orgm.paths' config/dotfiles.json
```

If individual scripts are listed, add all new `hypr-rofi-*`, `hypr-rofi-lib`, and `hypr-bluetooth-reconnect` paths under `shared.paths`.

- [ ] **Step 2: Remove active Fuzzel usage**

Run:

```bash
rg -n "fuzzel|hypr-fuzzel" config/shared config/hosts/orgm
```

Expected active Hyprland menu/keybinding/helper configs contain no Fuzzel references.

- [ ] **Step 3: Script validation**

Run:

```bash
bash -n config/shared/.local/bin/hypr-* config/shared/.local/bin/orgm-theme config/shared/.local/bin/waybar-*
```

Expected: no output, exit 0.

- [ ] **Step 4: Apply and diff**

Run:

```bash
distrobox-host-exec orgm-dot sync
distrobox-host-exec orgm-dot diff
```

Expected: `orgm-dot diff --host orgm` with no file diffs.

- [ ] **Step 5: Live smoke checks**

Run non-interactive checks:

```bash
distrobox-host-exec sh -lc 'HYPR_ROFI_ENV=$HOME/.config/rofi/hypr-menu.env bash -x ~/.local/bin/hypr-main-menu </dev/null >/tmp/hypr-main-menu.out 2>/tmp/hypr-main-menu.x || true; grep -E "HYPR_ROFI_SCALE|width|JetBrainsMono" /tmp/hypr-main-menu.x | head'
distrobox-host-exec sh -lc 'command -v hypr-rofi-window hypr-rofi-open-file hypr-rofi-calc hypr-bluetooth-reconnect'
```

Expected: commands exist; debug shows host sizing.

- [ ] **Step 6: Final commit and push**

```bash
git status --short
git push origin master
```

Expected: only unrelated `config/shared/.config/hypr/lua/autostart.lua` remains modified locally if still present; new work pushed.

---

## Self-review

Spec coverage:

- Shared Rofi env/sizing layer: Task 1.
- All menus/submenus use variables: Task 2.
- Remove active Fuzzel usage: Tasks 3 and 4.
- Waybar Bluetooth reconnect button: Task 5.
- Verification via orgm-dot and host checks: Task 6.

Placeholder scan:

- No `TBD` or unspecified implementation steps remain.

Scope check:

- One cohesive Hyprland launcher/menu refactor plus one Waybar action using the same Rofi layer. Fits one implementation plan.
