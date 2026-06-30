# ORGM Helper Restoration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore shell helpers as the default Hyprland/Waybar/menu integration layer, move focused Go helpers into `dotfiles`, and keep `nixos` as a separate package consumer.

**Architecture:** Do this in small SDD slices. First recover and inventory old helpers from git/backups, then restore shell helpers without rewiring callers, then migrate callers away from broad `orgm-hypr`, then split focused Go helpers into `orgm-wallpaper`, `orgm-calendar`, and `orgm-dot` under `dotfiles`. NixOS packaging changes come last.

**Tech Stack:** Shell helpers (`bash`/POSIX sh), Hyprland Lua config, Waybar JSON config, SwayNC CSS, Go helpers, Bats-style shell tests where existing patterns fit, Nix package definitions in separate `/home/osmarg/Hobby/nixos` repo.

---

## Current known context

- Work from `/home/osmarg/Hobby/dotfiles`.
- Keep `/home/osmarg/Hobby/nixos` separate.
- `dotfiles` currently has unrelated dirty files:
  - `config/shared/.config/hypr/lua/autostart.lua`
  - `config/shared/.config/hypr/lua/look-and-feel.lua`
  - `config/shared/.config/nwg-dock-hyprland/style.css`
  - `config/shared/.config/swaync/style.css`
- `nixos` currently has unrelated dirty files from recent ORGM work.
- Important deleted helper commit found in dotfiles: `b4ccf50` (`chore(dotfiles): remove orgm-hypr wrappers`).
- Deleted helper paths from `b4ccf50`:
  - `config/shared/.local/bin/brightness-osd`
  - `config/shared/.local/bin/fuzzel-calc`
  - `config/shared/.local/bin/fuzzel-hypr-window`
  - `config/shared/.local/bin/fuzzel-open-file`
  - `config/shared/.local/bin/fuzzel-open-file-dir`
  - `config/shared/.local/bin/fuzzel-open-file-terminal`
  - `config/shared/.local/bin/fuzzel-ssh-host`
  - `config/shared/.local/bin/fuzzel-tmux-arch`
  - `config/shared/.local/bin/hypr-bluetooth-menu`
  - `config/shared/.local/bin/hypr-current-wallpaper`
  - `config/shared/.local/bin/hypr-focus-notification-app`
  - `config/shared/.local/bin/hypr-fuzzel`
  - `config/shared/.local/bin/hypr-keybindings-help`
  - `config/shared/.local/bin/hypr-keyboard-menu`
  - `config/shared/.local/bin/hypr-kill-windows`
  - `config/shared/.local/bin/hypr-lock`
  - `config/shared/.local/bin/hypr-main-menu`
  - `config/shared/.local/bin/hypr-nwg-dock`
  - `config/shared/.local/bin/hypr-performance-menu`
  - `config/shared/.local/bin/hypr-power-menu`
  - `config/shared/.local/bin/hypr-random-wallpaper`
  - `config/shared/.local/bin/hypr-smart-run`
  - `config/shared/.local/bin/hypr-system-menu`
  - `config/shared/.local/bin/hypr-tools-menu`
  - `config/shared/.local/bin/hypr-webapp-maker`
  - `config/shared/.local/bin/hypr-webapp-remover`
  - `config/shared/.local/bin/hypr-wifi-menu`
  - `config/shared/.local/bin/hypr-workspace-button`
  - `config/shared/.local/bin/hypr-zen-new-window`
  - `config/shared/.local/bin/mic-volume-osd`
  - `config/shared/.local/bin/volume-osd`
  - `config/shared/.local/bin/waybar-date-es`
  - `config/shared/.local/bin/waybar-day-month-es`
  - `config/shared/.local/bin/waybar-swap-usage`
  - `config/shared/.local/bin/waybar-time-ampm`
  - `config/shared/.local/bin/waybar-watch`

## File structure to create/modify

### Dotfiles repo

- Create: `docs/orgm-helper-inventory.md` — generated inventory and ownership decision table.
- Create: `docs/orgm-helper-recovery.md` — exact recovery source for each restored helper: git commit/path or backup path.
- Restore: `config/shared/.local/bin/<helper>` — shell helpers listed above, one file per helper.
- Modify: `config/dotfiles.json` — add restored helpers to `shared.paths` if missing.
- Modify later: `config/shared/.config/hypr/lua/*.lua` — callers from `orgm-hypr` to shell helpers.
- Modify later: `config/shared/.config/waybar-hypr/config` and `config/shared/.config/waybar/config` — Waybar callers.
- Modify later: `config/shared/.config/swaync/config.json` — notification focus helper caller if needed.
- Create later: `cmd/orgm-wallpaper/`, `cmd/orgm-calendar/`, `cmd/orgm-dot/` — focused Go helpers moved from `/home/osmarg/Hobby/nixos`.
- Create later: `tests/helpers/*.bats.sh` — helper tests with stubbed commands.

### NixOS repo

- Modify later: `/home/osmarg/Hobby/nixos/nixos/packages/orgm-wallpaper.nix` — build `orgm-wallpaper` from dotfiles source.
- Modify later: `/home/osmarg/Hobby/nixos/nixos/packages/orgm-calendar.nix` — build `orgm-calendar` from dotfiles source.
- Modify later: `/home/osmarg/Hobby/nixos/nixos/packages/orgm-dot.nix` — build `orgm-dot` from dotfiles source.
- Modify later: `/home/osmarg/Hobby/nixos/nixos/profiles/hyprland.nix` — install focused helpers and remove broad `orgm-hypr` only after callers are migrated.

---

## Task 1: Create helper inventory from git history and backups

**Files:**
- Create: `docs/orgm-helper-inventory.md`
- Create: `docs/orgm-helper-recovery.md`

- [ ] **Step 1: Capture current repo status**

Run:

```bash
cd /home/osmarg/Hobby/dotfiles
git status --short > /tmp/dotfiles-status-before-helper-restore.txt
cd /home/osmarg/Hobby/nixos
git status --short > /tmp/nixos-status-before-helper-restore.txt
```

Expected:

```text
/tmp/dotfiles-status-before-helper-restore.txt exists and records dirty files.
/tmp/nixos-status-before-helper-restore.txt exists and records dirty files.
```

- [ ] **Step 2: Generate deleted helper list from dotfiles git**

Run:

```bash
cd /home/osmarg/Hobby/dotfiles
mkdir -p docs
{
  printf '# ORGM helper inventory\n\n'
  printf '## Dotfiles status before restoration\n\n```text\n'
  cat /tmp/dotfiles-status-before-helper-restore.txt
  printf '```\n\n'
  printf '## NixOS status before restoration\n\n```text\n'
  cat /tmp/nixos-status-before-helper-restore.txt
  printf '```\n\n'
  printf '## Deleted helper paths from git history\n\n'
  git show --name-only --pretty=format: b4ccf50 -- config/shared/.local/bin \
    | sort \
    | sed '/^$/d' \
    | sed 's#^#- #'
} > docs/orgm-helper-inventory.md
```

Expected:

```bash
rg -n 'hypr-random-wallpaper|waybar-date-es|brightness-osd' docs/orgm-helper-inventory.md
```

Expected output contains all three helper names.

- [ ] **Step 3: Search backup-looking locations without trusting them yet**

Run:

```bash
cd /home/osmarg/Hobby/dotfiles
{
  printf '# ORGM helper recovery sources\n\n'
  printf '## Git recovery source\n\n'
  printf 'Primary source: dotfiles commit `b4ccf50^` for files deleted by commit `b4ccf50`.\n\n'
  printf '## Backup-looking candidates\n\n```text\n'
  find /home/osmarg -maxdepth 5 \( -iname '*backup*' -o -iname '*.bak' -o -iname '*dotfiles*old*' -o -iname '*hypr*backup*' \) 2>/dev/null \
    | grep -E 'dotfiles|hypr|waybar|orgm|backup|bak' \
    | head -200
  printf '```\n\n'
} > docs/orgm-helper-recovery.md
```

Expected:

```bash
test -s docs/orgm-helper-recovery.md
```

Expected: exit code `0`.

- [ ] **Step 4: Add initial ownership table**

Append this exact table:

```bash
cat >> docs/orgm-helper-inventory.md <<'EOF'

## Target ownership

| Helper or area | Target owner | Recovery source | First action |
| --- | --- | --- | --- |
| `brightness-osd` | shell helper | `b4ccf50^` | restore and test notify payload |
| `volume-osd` | shell helper | `b4ccf50^` | restore and test notify payload |
| `mic-volume-osd` | shell helper | `b4ccf50^` | restore and test notify payload |
| `waybar-date-es` | shell helper | `b4ccf50^` | restore and test output |
| `waybar-day-month-es` | shell helper | `b4ccf50^` | restore and test output |
| `waybar-time-ampm` | shell helper | `b4ccf50^` | restore and test output |
| `waybar-swap-usage` | shell helper | `b4ccf50^` | restore and test meminfo parsing |
| `waybar-watch` | shell helper | `b4ccf50^` | restore and test print/launch plan |
| `hypr-main-menu` and submenus | shell helper | `b4ccf50^` | restore before changing keybindings |
| `hypr-power-menu` | shell helper | `b4ccf50^` | restore and test selection commands |
| `hypr-random-wallpaper` | shell helper + `orgm-wallpaper` | `b4ccf50^` plus NixOS Go wallpaper code | restore daemon, keep Go for data/thumbs |
| `fuzzel-*` helpers | shell helper | `b4ccf50^` | restore and test command generation |
| `hypr-workspace-button` | shell helper | `b4ccf50^` | restore and test JSON output/click command |
| `hypr-focus-notification-app` | shell helper | `b4ccf50^` | restore and wire SwayNC later |
| Wallpaper thumbnail/data | `orgm-wallpaper` Go | `/home/osmarg/Hobby/nixos/cmd/orgm-hypr` + `internal/wallpaper` | split after shell helpers exist |
| Calendar daemon | `orgm-calendar` Go | `/home/osmarg/Hobby/nixos/internal/calendar` | split after caller audit |
| Dotfile manager | `orgm-dot` Go | `/home/osmarg/Hobby/nixos/cmd/orgm-dot` + `internal/dot*` | move source to dotfiles, keep NixOS package consumer |
EOF
```

Expected:

```bash
rg -n 'orgm-wallpaper|orgm-calendar|orgm-dot|hypr-random-wallpaper' docs/orgm-helper-inventory.md
```

Expected output contains all four names.

- [ ] **Step 5: Commit inventory docs only if working tree policy allows**

Run:

```bash
cd /home/osmarg/Hobby/dotfiles
git status --short docs/orgm-helper-inventory.md docs/orgm-helper-recovery.md docs/superpowers/specs/2026-05-29-orgm-helper-restoration-design.md docs/superpowers/plans/2026-05-29-orgm-helper-restoration.md
```

Expected: only docs listed as untracked/modified for this task. If unrelated dirty files are present, do not include them.

Commit command when allowed:

```bash
git add docs/orgm-helper-inventory.md docs/orgm-helper-recovery.md docs/superpowers/specs/2026-05-29-orgm-helper-restoration-design.md docs/superpowers/plans/2026-05-29-orgm-helper-restoration.md
git commit -m "docs: plan orgm helper restoration"
```

Expected: commit succeeds or is intentionally skipped due existing dirty-tree policy.

---

## Task 2: Restore deleted shell helpers without changing callers

**Files:**
- Restore: all helper files deleted by commit `b4ccf50` under `config/shared/.local/bin/`
- Modify: `config/dotfiles.json`

- [ ] **Step 1: Restore helper files from parent of deletion commit**

Run:

```bash
cd /home/osmarg/Hobby/dotfiles
git checkout b4ccf50^ -- \
  config/shared/.local/bin/brightness-osd \
  config/shared/.local/bin/fuzzel-calc \
  config/shared/.local/bin/fuzzel-hypr-window \
  config/shared/.local/bin/fuzzel-open-file \
  config/shared/.local/bin/fuzzel-open-file-dir \
  config/shared/.local/bin/fuzzel-open-file-terminal \
  config/shared/.local/bin/fuzzel-ssh-host \
  config/shared/.local/bin/fuzzel-tmux-arch \
  config/shared/.local/bin/hypr-bluetooth-menu \
  config/shared/.local/bin/hypr-current-wallpaper \
  config/shared/.local/bin/hypr-focus-notification-app \
  config/shared/.local/bin/hypr-fuzzel \
  config/shared/.local/bin/hypr-keybindings-help \
  config/shared/.local/bin/hypr-keyboard-menu \
  config/shared/.local/bin/hypr-kill-windows \
  config/shared/.local/bin/hypr-lock \
  config/shared/.local/bin/hypr-main-menu \
  config/shared/.local/bin/hypr-nwg-dock \
  config/shared/.local/bin/hypr-performance-menu \
  config/shared/.local/bin/hypr-power-menu \
  config/shared/.local/bin/hypr-random-wallpaper \
  config/shared/.local/bin/hypr-smart-run \
  config/shared/.local/bin/hypr-system-menu \
  config/shared/.local/bin/hypr-tools-menu \
  config/shared/.local/bin/hypr-webapp-maker \
  config/shared/.local/bin/hypr-webapp-remover \
  config/shared/.local/bin/hypr-wifi-menu \
  config/shared/.local/bin/hypr-workspace-button \
  config/shared/.local/bin/hypr-zen-new-window \
  config/shared/.local/bin/mic-volume-osd \
  config/shared/.local/bin/volume-osd \
  config/shared/.local/bin/waybar-date-es \
  config/shared/.local/bin/waybar-day-month-es \
  config/shared/.local/bin/waybar-swap-usage \
  config/shared/.local/bin/waybar-time-ampm \
  config/shared/.local/bin/waybar-watch
chmod +x config/shared/.local/bin/*
```

Expected:

```bash
test -x config/shared/.local/bin/hypr-random-wallpaper
test -x config/shared/.local/bin/waybar-date-es
test -x config/shared/.local/bin/brightness-osd
```

Expected: all exit code `0`.

- [ ] **Step 2: Audit restored scripts for remaining broad `orgm-hypr` dependencies**

Run:

```bash
cd /home/osmarg/Hobby/dotfiles
rg -n 'orgm-hypr' config/shared/.local/bin > /tmp/restored-helper-orgm-hypr-refs.txt || true
cat /tmp/restored-helper-orgm-hypr-refs.txt
```

Expected: refs are visible and classified. Do not edit them in this task except for wallpaper script argument naming if it blocks tests.

- [ ] **Step 3: Add restored helpers to dotfiles manifest if missing**

Run:

```bash
cd /home/osmarg/Hobby/dotfiles
python - <<'PY'
import json
from pathlib import Path
manifest = Path('config/dotfiles.json')
data = json.loads(manifest.read_text())
paths = data.setdefault('shared', {}).setdefault('paths', [])
needed = ['.local/bin']
changed = False
for item in needed:
    if item not in paths:
        paths.append(item)
        changed = True
if changed:
    manifest.write_text(json.dumps(data, indent=2, ensure_ascii=False) + '\n')
print('changed=' + str(changed).lower())
PY
```

Expected: prints `changed=false` if `.local/bin` already tracked, or `changed=true` if manifest needed update.

- [ ] **Step 4: Syntax-check restored shell helpers**

Run:

```bash
cd /home/osmarg/Hobby/dotfiles
for f in config/shared/.local/bin/*; do
  [ -f "$f" ] || continue
  head -1 "$f" | grep -Eq 'sh|bash' || continue
  bash -n "$f" || exit 1
done
```

Expected: exit code `0`.

- [ ] **Step 5: Commit restored helpers as one reviewable unit**

Run:

```bash
cd /home/osmarg/Hobby/dotfiles
git status --short config/shared/.local/bin config/dotfiles.json docs/orgm-helper-inventory.md docs/orgm-helper-recovery.md
```

Expected: restored helpers and manifest/doc updates only. Commit when clean enough:

```bash
git add config/shared/.local/bin config/dotfiles.json docs/orgm-helper-inventory.md docs/orgm-helper-recovery.md
git commit -m "restore hypr shell helpers"
```

---

## Task 3: Add smoke tests for restored helpers before rewiring callers

**Files:**
- Create: `tests/helpers/hypr-shell-helpers.bats.sh`

- [ ] **Step 1: Create smoke test script**

Write this file:

```bash
cd /home/osmarg/Hobby/dotfiles
mkdir -p tests/helpers
cat > tests/helpers/hypr-shell-helpers.bats.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BIN="$ROOT/config/shared/.local/bin"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_executable() {
  local name="$1"
  [ -x "$BIN/$name" ] || fail "$name is not executable"
}

assert_syntax() {
  local name="$1"
  bash -n "$BIN/$name" || fail "$name syntax check failed"
}

for helper in \
  brightness-osd \
  volume-osd \
  mic-volume-osd \
  hypr-random-wallpaper \
  hypr-main-menu \
  hypr-power-menu \
  waybar-date-es \
  waybar-day-month-es \
  waybar-time-ampm \
  waybar-swap-usage \
  waybar-watch; do
  assert_executable "$helper"
  assert_syntax "$helper"
done

echo "hypr shell helper smoke tests passed"
EOF
chmod +x tests/helpers/hypr-shell-helpers.bats.sh
```

- [ ] **Step 2: Run smoke test**

Run:

```bash
cd /home/osmarg/Hobby/dotfiles
bash tests/helpers/hypr-shell-helpers.bats.sh
```

Expected:

```text
hypr shell helper smoke tests passed
```

- [ ] **Step 3: Commit smoke tests**

Run:

```bash
git add tests/helpers/hypr-shell-helpers.bats.sh
git commit -m "test: add hypr helper smoke checks"
```

Expected: commit succeeds if previous task committed, otherwise include test in same review slice only after checking status.

---

## Task 4: Restore random wallpaper daemon behavior

**Files:**
- Modify: `config/shared/.local/bin/hypr-random-wallpaper`
- Test: `tests/helpers/hypr-random-wallpaper.bats.sh`

- [ ] **Step 1: Write failing test for single daemon and 30-minute default**

Write this file:

```bash
cd /home/osmarg/Hobby/dotfiles
cat > tests/helpers/hypr-random-wallpaper.bats.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/config/shared/.local/bin/hypr-random-wallpaper"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

mkdir -p "$TMP/home/Pictures/Wallpapers" "$TMP/runtime" "$TMP/state" "$TMP/bin"
touch "$TMP/home/Pictures/Wallpapers/a.png"
cat > "$TMP/bin/hyprctl" <<'STUB'
#!/usr/bin/env bash
echo "hyprctl $*" >> "$CALLS"
STUB
chmod +x "$TMP/bin/hyprctl"

CALLS="$TMP/calls.log" PATH="$TMP/bin:$PATH" HOME="$TMP/home" XDG_RUNTIME_DIR="$TMP/runtime" XDG_STATE_HOME="$TMP/state" SWAY_WALLPAPER_INTERVAL=1800 "$SCRIPT" next

grep -q 'hyprctl hyprpaper' "$CALLS" || grep -q 'hyprctl dispatch' "$CALLS" || grep -q 'hyprctl keyword' "$CALLS" || fail "wallpaper script did not call hyprctl in next mode"
[ -s "$TMP/state/hypr-random-wallpaper.current" ] || [ -s "$TMP/runtime/hypr-random-wallpaper.current" ] || fail "current wallpaper state was not written"

echo "hypr random wallpaper smoke test passed"
EOF
chmod +x tests/helpers/hypr-random-wallpaper.bats.sh
```

- [ ] **Step 2: Run test and observe current behavior**

Run:

```bash
cd /home/osmarg/Hobby/dotfiles
bash tests/helpers/hypr-random-wallpaper.bats.sh
```

Expected: If restored historical helper already passes, keep it. If it fails because command changed to `orgm-hypr`, patch only the minimal wallpaper command path.

- [ ] **Step 3: Patch `hypr-random-wallpaper` only if test fails**

If it fails due missing direct wallpaper command, update the script to use direct Hyprland wallpaper flow or `orgm-wallpaper` only for expensive data/thumb operations. Preserve these behaviors:

```bash
interval="${SWAY_WALLPAPER_INTERVAL:-1800}"
current_file="${XDG_STATE_HOME:-$HOME/.local/state}/hypr-random-wallpaper.current"
daemon_pid_file="${XDG_RUNTIME_DIR:-/tmp}/hypr-random-wallpaper.daemon.pid"
```

Do not remove `daemon` and `next` subcommands.

- [ ] **Step 4: Re-run wallpaper test**

Run:

```bash
cd /home/osmarg/Hobby/dotfiles
bash tests/helpers/hypr-random-wallpaper.bats.sh
```

Expected:

```text
hypr random wallpaper smoke test passed
```

- [ ] **Step 5: Commit wallpaper daemon restoration**

Run:

```bash
git add config/shared/.local/bin/hypr-random-wallpaper tests/helpers/hypr-random-wallpaper.bats.sh
git commit -m "restore hypr wallpaper daemon helper"
```

---

## Task 5: Rewire dotfiles callers from broad `orgm-hypr` to shell helpers

**Files:**
- Modify: `config/shared/.config/hypr/lua/autostart.lua`
- Modify: `config/shared/.config/hypr/lua/keybindings.lua`
- Modify: `config/shared/.config/hypr/lua/look-and-feel.lua`
- Modify: `config/shared/.config/waybar-hypr/config`
- Modify: `config/shared/.config/waybar/config`
- Modify: `config/shared/.config/swaync/config.json`

- [ ] **Step 1: Create caller audit before edits**

Run:

```bash
cd /home/osmarg/Hobby/dotfiles
rg -n 'orgm-hypr' config/shared/.config config/shared/.local/bin > docs/orgm-hypr-callers-before-shell-restore.txt || true
cat docs/orgm-hypr-callers-before-shell-restore.txt
```

Expected: every caller is visible.

- [ ] **Step 2: Replace caller groups one by one**

Use these mappings:

```text
orgm-hypr waybar date --format day-month-es  -> waybar-day-month-es
orgm-hypr waybar date --format time-ampm     -> waybar-time-ampm
orgm-hypr waybar date --format date-es       -> waybar-date-es
orgm-hypr waybar swap-usage                  -> waybar-swap-usage
orgm-hypr waybar watch ~/.config/waybar-hypr -> waybar-watch ~/.config/waybar-hypr
orgm-hypr menu main                          -> hypr-main-menu
orgm-hypr session lock --force               -> hypr-lock
orgm-hypr windows kill-menu                  -> hypr-kill-windows
orgm-hypr windows switch --launcher fuzzel   -> fuzzel-hypr-window
orgm-hypr dock start                         -> hypr-nwg-dock
orgm-hypr notify focus-app                   -> hypr-focus-notification-app
orgm-hypr wallpaper restore                  -> hypr-random-wallpaper restore
orgm-hypr wallpaper picker-daemon            -> orgm-wallpaper picker-daemon, after orgm-wallpaper exists
```

After each file edit, run:

```bash
luac -p config/shared/.config/hypr/lua/autostart.lua config/shared/.config/hypr/lua/keybindings.lua config/shared/.config/hypr/lua/look-and-feel.lua
python -m json.tool config/shared/.config/swaync/config.json >/dev/null
```

Expected: exit code `0`.

- [ ] **Step 3: Audit remaining `orgm-hypr` refs**

Run:

```bash
cd /home/osmarg/Hobby/dotfiles
rg -n 'orgm-hypr' config/shared/.config config/shared/.local/bin || true
```

Expected: only temporary compatibility refs remain, preferably wallpaper refs awaiting `orgm-wallpaper` split.

- [ ] **Step 4: Check dotfile sync diff**

Run:

```bash
cd /home/osmarg/Hobby/dotfiles
distrobox-host-exec orgm-dot diff
```

Expected: diff only contains intended helper/caller changes.

- [ ] **Step 5: Commit caller rewiring**

Run:

```bash
git add config/shared/.config/hypr config/shared/.config/waybar config/shared/.config/waybar-hypr config/shared/.config/swaync docs/orgm-hypr-callers-before-shell-restore.txt
git commit -m "wire hypr configs back to shell helpers"
```

---

## Task 6: Move focused Go helpers from NixOS into dotfiles

**Files:**
- Create: `go.mod`
- Create: `cmd/orgm-wallpaper/main.go`
- Create: `cmd/orgm-calendar/main.go`
- Create: `cmd/orgm-dot/main.go`
- Create/Copy: `internal/wallpaper/**`
- Create/Copy: `internal/calendar/**`
- Create/Copy: `internal/dot*/**`

- [ ] **Step 1: Copy Go sources from NixOS to dotfiles**

Run:

```bash
cd /home/osmarg/Hobby/dotfiles
cp /home/osmarg/Hobby/nixos/go.mod ./go.mod
mkdir -p cmd internal
cp -R /home/osmarg/Hobby/nixos/internal/wallpaper internal/wallpaper
cp -R /home/osmarg/Hobby/nixos/internal/calendar internal/calendar
cp -R /home/osmarg/Hobby/nixos/internal/cli internal/cli
cp -R /home/osmarg/Hobby/nixos/internal/dotadd internal/dotadd
cp -R /home/osmarg/Hobby/nixos/internal/dotcli internal/dotcli
cp -R /home/osmarg/Hobby/nixos/internal/dotconfig internal/dotconfig
cp -R /home/osmarg/Hobby/nixos/internal/dotdaemon internal/dotdaemon
cp -R /home/osmarg/Hobby/nixos/internal/dotdiff internal/dotdiff
cp -R /home/osmarg/Hobby/nixos/internal/dotinstall internal/dotinstall
cp -R /home/osmarg/Hobby/nixos/internal/dotmanifest internal/dotmanifest
cp -R /home/osmarg/Hobby/nixos/internal/dotpaths internal/dotpaths
cp -R /home/osmarg/Hobby/nixos/internal/dotsync internal/dotsync
cp -R /home/osmarg/Hobby/nixos/cmd/orgm-dot cmd/orgm-dot
```

Expected: directories exist.

- [ ] **Step 2: Create `orgm-wallpaper` command from old wallpaper command surface**

Start by copying the minimal wallpaper command code from `/home/osmarg/Hobby/nixos/cmd/orgm-hypr/main.go` into `cmd/orgm-wallpaper/main.go`. Keep only wallpaper subcommands:

```text
data
status
clean-thumbs
restore
pick
picker-daemon
daemon
```

Expected first compile may fail due missing helper functions; copy only helper functions needed by wallpaper command.

- [ ] **Step 3: Create `orgm-calendar` command wrapper**

Write `cmd/orgm-calendar/main.go`:

```go
package main

import (
	"os"

	"github.com/osmargm1202/nixos/internal/calendar"
)

func main() {
	if err := calendar.Run(os.Args[1:], os.Stdout, os.Stderr); err != nil {
		_, _ = os.Stderr.WriteString(err.Error() + "\n")
		os.Exit(1)
	}
}
```

Then update module path if `go.mod` is changed from `github.com/osmargm1202/nixos` to a dotfiles module path.

- [ ] **Step 4: Run Go tests**

Run:

```bash
cd /home/osmarg/Hobby/dotfiles
go test ./...
```

Expected: either pass or fail only on module path/import issues introduced by the move. Fix module paths consistently before proceeding.

- [ ] **Step 5: Commit focused Go helper import**

Run:

```bash
git add go.mod cmd internal
git commit -m "feat: move focused orgm go helpers to dotfiles"
```

---

## Task 7: Update NixOS packaging to consume dotfiles Go helpers

**Files in `/home/osmarg/Hobby/nixos`:**
- Create: `nixos/packages/orgm-wallpaper.nix`
- Create: `nixos/packages/orgm-calendar.nix`
- Modify: `nixos/packages/orgm-dot.nix`
- Modify: `flake.nix`
- Modify: `nixos/profiles/hyprland.nix`

- [ ] **Step 1: Add package expressions that point at dotfiles source**

Use local source first for development:

```nix
src = builtins.path {
  path = /home/osmarg/Hobby/dotfiles;
  name = "dotfiles-orgm-source";
};
```

Expected: development build uses current dotfiles checkout.

- [ ] **Step 2: Build focused packages**

Run:

```bash
cd /home/osmarg/Hobby/nixos
distrobox-host-exec nix build .#orgm-wallpaper --no-link
distrobox-host-exec nix build .#orgm-calendar --no-link
distrobox-host-exec nix build .#orgm-dot --no-link
```

Expected: all three builds exit `0`.

- [ ] **Step 3: Keep `orgm-hypr` package until caller audit is clean**

Run:

```bash
cd /home/osmarg/Hobby/dotfiles
rg -n 'orgm-hypr' config/shared || true
cd /home/osmarg/Hobby/nixos
rg -n 'orgm-hypr' nixos flake.nix tests || true
```

Expected: do not remove `orgm-hypr` package while refs remain.

- [ ] **Step 4: Commit NixOS packaging changes**

Run:

```bash
cd /home/osmarg/Hobby/nixos
git add nixos/packages flake.nix nixos/profiles/hyprland.nix
git commit -m "package focused orgm helpers from dotfiles"
```

---

## Task 8: Final audit and sync

**Files:**
- Modify: `docs/orgm-helper-inventory.md`
- Modify: `docs/orgm-helper-recovery.md`

- [ ] **Step 1: Audit all active broad `orgm-hypr` refs**

Run:

```bash
cd /home/osmarg/Hobby/dotfiles
rg -n 'orgm-hypr' config/shared docs tests || true
cd /home/osmarg/Hobby/nixos
rg -n 'orgm-hypr' flake.nix nixos tests cmd internal docs || true
```

Expected: remaining refs are compatibility docs/tests only, or explicitly listed in `docs/orgm-helper-inventory.md`.

- [ ] **Step 2: Run dotfiles verification**

Run:

```bash
cd /home/osmarg/Hobby/dotfiles
bash tests/helpers/hypr-shell-helpers.bats.sh
bash tests/helpers/hypr-random-wallpaper.bats.sh
go test ./...
luac -p config/shared/.config/hypr/lua/*.lua
python -m json.tool config/shared/.config/swaync/config.json >/dev/null
distrobox-host-exec orgm-dot diff
```

Expected: tests pass, Lua/JSON validate, diff shows intended changes.

- [ ] **Step 3: Sync dotfiles after reviewing diff**

Run only after reading `orgm-dot diff` output:

```bash
cd /home/osmarg/Hobby/dotfiles
distrobox-host-exec orgm-dot sync
```

Expected: exit code `0`.

- [ ] **Step 4: Run NixOS package verification**

Run:

```bash
cd /home/osmarg/Hobby/nixos
distrobox-host-exec nix build .#orgm-wallpaper --no-link
distrobox-host-exec nix build .#orgm-calendar --no-link
distrobox-host-exec nix build .#orgm-dot --no-link
```

Expected: all builds exit `0`.

- [ ] **Step 5: Manual smoke list**

Manually verify in Hyprland session:

```text
- Hypr main menu opens.
- Power menu opens.
- Waybar date/time render.
- Waybar swap renders.
- Workspace buttons render and click.
- Volume/mic/brightness OSD shows notifications.
- Wallpaper picker opens and thumbnails load quickly.
- `hypr-random-wallpaper next` changes wallpaper.
- `hypr-random-wallpaper daemon` keeps one daemon and uses 30-minute default interval.
- Calendar daemon starts and does not duplicate notifications.
- `orgm-dot diff` and `orgm-dot sync` work from host.
```

- [ ] **Step 6: Commit final audit docs**

Run:

```bash
cd /home/osmarg/Hobby/dotfiles
git add docs/orgm-helper-inventory.md docs/orgm-helper-recovery.md
git commit -m "docs: record orgm helper migration audit"
```

---

## Self-review checklist

- Spec coverage:
  - Shell helpers default: Tasks 2, 3, 5.
  - Search git/backups: Task 1.
  - Restore 30-minute wallpaper daemon: Task 4.
  - Keep repos separate: Tasks 6 and 7 explicitly use dotfiles source and NixOS consumer packaging.
  - Go in dotfiles: Task 6.
  - NixOS packages focused helpers: Task 7.
  - Verification: Task 8.
- No broad implementation before inventory.
- No NixOS repo merge.
- Dirty tree handling included.
- `orgm-hypr` removal is gated by caller audit.
