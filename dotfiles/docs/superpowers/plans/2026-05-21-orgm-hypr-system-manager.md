# orgm-hypr System Manager Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a single fast Go binary, `orgm-hypr`, to replace performance-sensitive and Hyprland-specific shell scripts while keeping small wrapper compatibility during migration.

**Architecture:** `orgm-hypr` is a focused Hyprland/NixOS system manager, not a replacement for the cross-platform `dot` tool. It owns wallpaper, picker daemon IPC, Waybar modules, dock/window helpers, Zen launch behavior, menus, updates, and Hyprland session utilities. Existing shell script names remain as thin wrappers until configs are migrated.

**Tech Stack:** Go 1.23+, Nix `buildGoModule`, Hyprland IPC via `hyprctl -j` first then optional socket client, Quickshell JSON trigger files, `fuzzel`/`rofi` external menus, `ffmpeg` for thumbnails, `mpvpaper`/`hyprpaper` for wallpaper backends.

---

## Scope

### In scope

- `orgm-hypr` Go binary for Hyprland-specific desktop management.
- Compatibility wrappers for current script names.
- Nix package integration.
- Incremental migration with tests after each subsystem.
- Quickshell picker coordination and wallpaper thumbnail cache.
- Waybar custom module outputs/click handlers.
- Dock, Zen, launcher/menu helpers, update status, system menus.

### Out of scope

- Replacing `dot.sh` now. `dot` remains separate because it serves non-Hyprland hosts too.
- Rewriting Sway/Labwc scripts unless shared code emerges later.
- Replacing every tiny one-liner immediately. Migrate by risk/performance first.

---

## Current Script Inventory

### High-priority Hyprland scripts

- `hypr-random-wallpaper` — static/live wallpaper, Quickshell picker data, thumbnails, mpvpaper/hyprpaper process control.
- `hypr-nwg-dock` — dock lifecycle/launch.
- `hypr-zen-new-window` — Zen Browser launch/window behavior.
- `hypr-smart-run` — smart app launcher.
- `hypr-workspace-button` — Waybar workspace status/click helpers.
- `waybar-watch` — Waybar lifecycle/reload.
- `hypr-update-daemon`, `hypr-update-status`, `hypr-update-menu` — updates/status/menu.
- `hypr-main-menu`, `hypr-tools-menu`, `hypr-system-menu`, `hypr-performance-menu`, `hypr-power-menu`, `hypr-wifi-menu`, `hypr-bluetooth-menu`, `hypr-keyboard-menu` — menu layer.
- `hypr-keybindings-help` — help output.
- `hypr-webapp-maker`, `hypr-webapp-remover` — webapp desktop files.
- `hypr-kill-windows`, `hypr-focus-notification-app`, `hypr-current-wallpaper` — focused utilities.

### Keep separate for now

- `dot`, `dot.sh` — cross-host dotfile manager.
- `sway-*`, `labwc-*` equivalents — non-Hyprland sessions.
- Generic `fuzzel-*` utilities — migrate only when shared launcher code is stable.

---

## Target CLI Shape

```bash
orgm-hypr wallpaper pick
orgm-hypr wallpaper restore
orgm-hypr wallpaper set-static PATH
orgm-hypr wallpaper set-video PATH
orgm-hypr wallpaper carousel static
orgm-hypr wallpaper carousel video
orgm-hypr wallpaper warm-page static 0 --page-size 16
orgm-hypr wallpaper picker-daemon

orgm-hypr waybar workspace status 1
orgm-hypr waybar workspace click 1
orgm-hypr waybar date day-month
orgm-hypr waybar date time
orgm-hypr waybar updates status
orgm-hypr waybar wallpaper current
orgm-hypr waybar watch --config ~/.config/waybar-hypr

orgm-hypr dock start
orgm-hypr dock stop
orgm-hypr dock toggle
orgm-hypr dock status

orgm-hypr zen new-window
orgm-hypr smart-run
orgm-hypr menu main
orgm-hypr menu tools
orgm-hypr menu system
orgm-hypr menu performance
orgm-hypr menu power
orgm-hypr menu wifi
orgm-hypr menu bluetooth
orgm-hypr menu keyboard

orgm-hypr updates daemon
orgm-hypr updates status
orgm-hypr updates menu

orgm-hypr webapp make
orgm-hypr webapp remove
orgm-hypr windows kill
orgm-hypr notify focus-app
```

Compatibility wrappers during migration:

```sh
#!/bin/sh
exec orgm-hypr wallpaper "$@"
```

Example: `hypr-random-wallpaper pick` remains working until keybinds are migrated.

---

## File Structure

### Create

- `go.mod` — Go module definition.
- `cmd/orgm-hypr/main.go` — CLI entrypoint and command routing.
- `internal/cli/cli.go` — argument parsing helpers, exit/error formatting.
- `internal/paths/paths.go` — XDG paths, default wallpaper dirs, runtime/state paths.
- `internal/run/run.go` — command execution, detached process helpers, PID validation.
- `internal/menu/menu.go` — fuzzel/rofi menu interface.
- `internal/hypr/hyprctl.go` — Hyprland calls, JSON parsing, workspace/window helpers.
- `internal/wallpaper/wallpaper.go` — wallpaper state, static/live apply, picker JSON, thumbnails.
- `internal/wallpaper/wallpaper_test.go` — wallpaper unit tests.
- `internal/waybar/waybar.go` — Waybar custom outputs and actions.
- `internal/waybar/waybar_test.go` — Waybar module tests.
- `internal/dock/dock.go` — NWG dock lifecycle.
- `internal/zen/zen.go` — Zen launch behavior.
- `internal/updates/updates.go` — update daemon/status/menu.
- `internal/webapp/webapp.go` — webapp maker/remover.
- `internal/menus/menus.go` — high-level menus.
- `nixos/packages/orgm-hypr.nix` — package build definition if repo uses local package file.
- `tests/orgm-hypr.bats.sh` — integration smoke tests around wrappers/CLI.

### Modify

- `nixos/profiles/hyprland.nix` — add `orgm-hypr` package, later remove obsolete runtime deps if replaced.
- `config/shared/.config/hypr/20-autostart.conf` — migrate scripts to `orgm-hypr` commands phase-by-phase.
- `config/shared/.config/hypr/70-keybindings.conf` — migrate keybinds phase-by-phase.
- `config/shared/.config/hypr/lua/autostart.lua` — parity with autostart conf.
- `config/shared/.config/hypr/lua/keybindings.lua` — parity with keybind conf.
- `config/shared/.config/waybar-hypr/config` — migrate custom module exec/on-click commands.
- `config/shared/.local/bin/*` wrappers — replace selected scripts with `exec orgm-hypr ...` wrappers.

---

## Phase 0: Foundation

**Goal:** Add compile/test/package skeleton without changing behavior.

**Files:**

- Create: `go.mod`
- Create: `cmd/orgm-hypr/main.go`
- Create: `internal/cli/cli.go`
- Create: `internal/paths/paths.go`
- Create: `internal/run/run.go`
- Create: `tests/orgm-hypr.bats.sh`

- [ ] **Step 1: Add Go module**

Create `go.mod`:

```go
module github.com/osmarg/dotfiles/orgm-hypr

go 1.23
```

- [ ] **Step 2: Add CLI skeleton**

Create `cmd/orgm-hypr/main.go`:

```go
package main

import (
	"fmt"
	"os"
)

func main() {
	if len(os.Args) < 2 {
		usage()
		os.Exit(2)
	}

	switch os.Args[1] {
	case "version":
		fmt.Println("orgm-hypr dev")
	case "wallpaper", "waybar", "dock", "zen", "menu", "updates", "webapp", "windows", "notify", "smart-run":
		fmt.Fprintf(os.Stderr, "%s: command group not implemented yet\n", os.Args[1])
		os.Exit(2)
	default:
		usage()
		os.Exit(2)
	}
}

func usage() {
	fmt.Fprintln(os.Stderr, "usage: orgm-hypr [version|wallpaper|waybar|dock|zen|menu|updates|webapp|windows|notify|smart-run] ...")
}
```

- [ ] **Step 3: Add first smoke test**

Create `tests/orgm-hypr.bats.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$REPO_DIR/result-bin/orgm-hypr"

fail() { echo "FAIL: $*" >&2; exit 1; }

mkdir -p "$REPO_DIR/result-bin"
go build -o "$BIN" "$REPO_DIR/cmd/orgm-hypr"

version="$($BIN version)"
[ "$version" = "orgm-hypr dev" ] || fail "unexpected version output: $version"

echo "orgm-hypr smoke tests passed"
```

- [ ] **Step 4: Run tests**

```bash
go test ./...
bash tests/orgm-hypr.bats.sh
```

Expected:

```text
?   github.com/osmarg/dotfiles/orgm-hypr/cmd/orgm-hypr [no test files]
orgm-hypr smoke tests passed
```

- [ ] **Step 5: Commit**

```bash
git add go.mod cmd/orgm-hypr internal tests/orgm-hypr.bats.sh
git commit -m "feat(hypr): add orgm-hypr skeleton"
```

---

## Phase 1: Wallpaper Backend Migration

**Goal:** Move `hypr-random-wallpaper` into Go first, because it is already performance-sensitive and active.

**Files:**

- Create: `internal/wallpaper/wallpaper.go`
- Create: `internal/wallpaper/wallpaper_test.go`
- Modify: `cmd/orgm-hypr/main.go`
- Modify: `config/shared/.local/bin/hypr-random-wallpaper`
- Keep: `config/shared/.config/quickshell/wallpaper-picker/shell.qml`

### Behavior to preserve

- Static wallpaper via `hyprpaper`.
- Live wallpaper via `mpvpaper`, with NVIDIA offload detection.
- `pick`, `restore`, `set-static`, `set-video`, `carousel`, `warm-page`, `picker-daemon`.
- State files remain compatible:
  - `${XDG_STATE_HOME:-~/.local/state}/hypr-wallpaper/state`
  - `wallpaper-picker.json`
  - `wallpaper-picker.tsv`
  - per-folder `.thumb/*.jpg`

- [ ] **Step 1: Port path/state helpers**

Implement Go equivalents for:

- XDG state/runtime/config paths
- wallpaper directories
- state read/write
- current mode/path

Test cases:

- default paths with fake `$HOME`
- `XDG_STATE_HOME` override
- mode/path read/write roundtrip

- [ ] **Step 2: Port wallpaper scanning**

Implement:

- static extensions: `.jpg`, `.jpeg`, `.png`, `.webp`
- video extensions: `.mp4`, `.mkv`, `.webm`, `.mov`, `.m4v`
- prune `.thumb`
- sorted output

Test cases:

- `.thumb` ignored
- static/video sets not mixed
- deterministic sorting

- [ ] **Step 3: Port picker JSON generation**

Implement one-pass JSON generation in Go. No Python dependency after this phase.

Output shape must remain:

```json
{
  "mode": "static",
  "title": "Normal wallpapers",
  "applyCommand": "set-static",
  "script": "orgm-hypr",
  "current": "",
  "items": [
    { "name": "a.png", "path": "/x/a.png", "thumb": "/x/.thumb/a.png.jpg" }
  ]
}
```

Use atomic write:

```text
wallpaper-picker.json.tmp.<pid> -> rename wallpaper-picker.json
```

- [ ] **Step 4: Port thumbnail warming**

Implement:

```bash
orgm-hypr wallpaper warm-page static 0 --page-size 16
```

Behavior:

- read manifest
- process only rows for page
- skip existing `.thumb`
- call ffmpeg with same filters

- [ ] **Step 5: Port apply/restore/live process control**

Implement:

- `set-static`
- `set-video`
- `restore`
- scoped `mpvpaper` cleanup
- PID validation
- NVIDIA offload
- no success notifications

- [ ] **Step 6: Wrapper compatibility**

Replace `config/shared/.local/bin/hypr-random-wallpaper` with:

```sh
#!/bin/sh
exec orgm-hypr wallpaper "$@"
```

Keep tests pointed at wrapper until configs are migrated.

- [ ] **Step 7: Run tests**

```bash
go test ./...
bash tests/orgm-hypr.bats.sh
bash tests/hypr-random-wallpaper.bats.sh
```

- [ ] **Step 8: Commit**

```bash
git add cmd internal config/shared/.local/bin/hypr-random-wallpaper tests
git commit -m "feat(hypr): move wallpaper manager to orgm-hypr"
```

---

## Phase 2: Quickshell Picker Daemon + IPC Contract

**Goal:** Make picker coordination explicit and testable.

**Files:**

- Modify: `internal/wallpaper/wallpaper.go`
- Modify: `config/shared/.config/quickshell/wallpaper-picker/shell.qml`
- Modify: `config/shared/.config/hypr/20-autostart.conf`
- Modify: `config/shared/.config/hypr/lua/autostart.lua`

Commands:

```bash
orgm-hypr wallpaper picker-daemon
orgm-hypr wallpaper picker-status
orgm-hypr wallpaper picker-stop
```

Acceptance:

- daemon starts hidden
- JSON update shows panel
- duplicate launch prevented by PID file and command validation
- fallback starts picker only when not running

Testing:

```bash
orgm-hypr wallpaper picker-status
orgm-hypr wallpaper carousel static
time orgm-hypr wallpaper carousel static
```

Expected:

- `carousel static` under 200ms with 500 wallpapers and daemon running
- one Quickshell process only

Commit:

```bash
git commit -m "feat(hypr): daemonize wallpaper picker IPC"
```

---

## Phase 3: Waybar Custom Modules

**Goal:** Replace frequent Waybar shell calls with fast Go subcommands.

**Files:**

- Create: `internal/waybar/waybar.go`
- Modify: `config/shared/.config/waybar-hypr/config`
- Replace wrapper: `hypr-workspace-button`
- Optional wrappers: `waybar-date-es`, `waybar-day-month-es`, `waybar-time-ampm`, `waybar-swap-usage`, `hypr-update-status`, `hypr-current-wallpaper`

Commands:

```bash
orgm-hypr waybar workspace status 1
orgm-hypr waybar workspace click 1
orgm-hypr waybar date day-month
orgm-hypr waybar date time
orgm-hypr waybar date full
orgm-hypr waybar memory swap
orgm-hypr waybar updates status
orgm-hypr waybar wallpaper current
```

Migration map:

```text
hypr-workspace-button status N -> orgm-hypr waybar workspace status N
hypr-workspace-button click N  -> orgm-hypr waybar workspace click N
waybar-day-month-es            -> orgm-hypr waybar date day-month
waybar-time-ampm               -> orgm-hypr waybar date time
waybar-date-es                 -> orgm-hypr waybar date full
waybar-swap-usage              -> orgm-hypr waybar memory swap
hypr-update-status             -> orgm-hypr waybar updates status
hypr-current-wallpaper         -> orgm-hypr waybar wallpaper current
```

Acceptance:

- Waybar loads with same visual output.
- Workspace click behavior unchanged.
- Status commands complete under 30ms each.

Commit:

```bash
git commit -m "feat(hypr): move waybar helpers to orgm-hypr"
```

---

## Phase 4: Dock Management

**Goal:** Replace `hypr-nwg-dock` shell lifecycle with Go.

**Files:**

- Create: `internal/dock/dock.go`
- Modify: `config/shared/.config/hypr/70-keybindings.conf` if dock keybind exists
- Modify: Waybar dock click handlers if present
- Replace wrapper: `hypr-nwg-dock`

Commands:

```bash
orgm-hypr dock start
orgm-hypr dock stop
orgm-hypr dock toggle
orgm-hypr dock status
```

Acceptance:

- single dock process
- stale PID removed
- restart safe after Hyprland reload
- no broad kill unless command line matches dock binary/config

Commit:

```bash
git commit -m "feat(hypr): manage dock with orgm-hypr"
```

---

## Phase 5: Zen + Smart Launcher

**Goal:** Centralize launch/window behavior.

**Files:**

- Create: `internal/zen/zen.go`
- Create: `internal/launcher/launcher.go`
- Replace wrappers: `hypr-zen-new-window`, `hypr-smart-run`
- Modify keybinds:
  - `SUPER+W`
  - `SUPER+A`

Commands:

```bash
orgm-hypr zen new-window
orgm-hypr smart-run
orgm-hypr launcher window
orgm-hypr launcher file
orgm-hypr launcher calc
orgm-hypr launcher ssh
```

Acceptance:

- `SUPER+W` opens Zen as current behavior.
- `SUPER+A` smart-run behavior unchanged.
- fallback if app missing prints clear stderr error.

Commit:

```bash
git commit -m "feat(hypr): move launch helpers to orgm-hypr"
```

---

## Phase 6: Menus

**Goal:** Replace menu scripts while keeping fuzzel UI.

**Files:**

- Create: `internal/menu/menu.go`
- Create: `internal/menus/menus.go`
- Replace wrappers:
  - `hypr-main-menu`
  - `hypr-tools-menu`
  - `hypr-system-menu`
  - `hypr-performance-menu`
  - `hypr-power-menu`
  - `hypr-wifi-menu`
  - `hypr-bluetooth-menu`
  - `hypr-keyboard-menu`

Commands:

```bash
orgm-hypr menu main
orgm-hypr menu tools
orgm-hypr menu system
orgm-hypr menu performance
orgm-hypr menu power
orgm-hypr menu wifi
orgm-hypr menu bluetooth
orgm-hypr menu keyboard
```

Acceptance:

- same menu entries
- same actions
- errors only when action fails
- no success notifications unless currently expected

Commit:

```bash
git commit -m "feat(hypr): move system menus to orgm-hypr"
```

---

## Phase 7: Updates Service

**Goal:** Replace update daemon/status/menu shell scripts.

**Files:**

- Create: `internal/updates/updates.go`
- Replace wrappers:
  - `hypr-update-daemon`
  - `hypr-update-status`
  - `hypr-update-menu`
- Modify autostart:
  - `hypr-update-daemon` -> `orgm-hypr updates daemon`

Commands:

```bash
orgm-hypr updates daemon
orgm-hypr updates status
orgm-hypr updates menu
orgm-hypr updates check-now
```

Acceptance:

- Waybar update module remains fast.
- daemon writes compact state file.
- manual menu can trigger check/install according to existing behavior.

Commit:

```bash
git commit -m "feat(hypr): move update status to orgm-hypr"
```

---

## Phase 8: Webapps + Misc Window Helpers

**Goal:** Move remaining Hyprland utilities.

**Files:**

- Create: `internal/webapp/webapp.go`
- Create: `internal/windows/windows.go`
- Create: `internal/notify/notify.go`
- Replace wrappers:
  - `hypr-webapp-maker`
  - `hypr-webapp-remover`
  - `hypr-kill-windows`
  - `hypr-focus-notification-app`
  - `hypr-keybindings-help`

Commands:

```bash
orgm-hypr webapp make
orgm-hypr webapp remove
orgm-hypr windows kill
orgm-hypr notify focus-app
orgm-hypr help keybindings
```

Acceptance:

- desktop file generation unchanged
- kill window behavior unchanged but safer PID/window matching
- keybindings help reflects current config

Commit:

```bash
git commit -m "feat(hypr): move remaining helpers to orgm-hypr"
```

---

## Phase 9: Config Migration and Cleanup

**Goal:** Replace script references in Hyprland/Waybar configs with `orgm-hypr`, then delete wrappers where safe.

**Files:**

- Modify: `config/shared/.config/hypr/20-autostart.conf`
- Modify: `config/shared/.config/hypr/70-keybindings.conf`
- Modify: `config/shared/.config/hypr/lua/autostart.lua`
- Modify: `config/shared/.config/hypr/lua/keybindings.lua`
- Modify: `config/shared/.config/waybar-hypr/config`
- Delete or keep wrappers based on compatibility needs

Migration examples:

```text
~/.local/bin/hypr-random-wallpaper pick -> orgm-hypr wallpaper pick
~/.local/bin/hypr-nwg-dock              -> orgm-hypr dock start
~/.local/bin/hypr-zen-new-window        -> orgm-hypr zen new-window
~/.local/bin/hypr-smart-run             -> orgm-hypr smart-run
~/.local/bin/hypr-workspace-button ...  -> orgm-hypr waybar workspace ...
```

Acceptance:

- `rg '~/.local/bin/hypr-|waybar-' config/shared/.config/hypr config/shared/.config/waybar-hypr` returns only intentionally retained wrappers.
- `hyprctl reload` works.
- Waybar reload works.
- Wallpaper picker appears under 200ms with daemon running.

Commit:

```bash
git commit -m "refactor(hypr): route configs through orgm-hypr"
```

---

## Nix Packaging Plan

Preferred package:

```nix
buildGoModule {
  pname = "orgm-hypr";
  version = "0.1.0";
  src = ../.;
  subPackages = [ "cmd/orgm-hypr" ];
  vendorHash = null;
}
```

Runtime dependencies remain system packages:

- `hyprpaper`
- `mpvpaper`
- `quickshell`
- `ffmpeg`
- `fuzzel`
- `rofi` fallback
- `hyprctl` from Hyprland
- `nwg-dock-hyprland` while dock still uses it

After Phase 1, remove `python3Minimal` if only wallpaper JSON used it and no other script needs it.

---

## Testing Strategy

### Go unit tests

```bash
go test ./...
```

### Shell compatibility tests

```bash
bash tests/orgm-hypr.bats.sh
bash tests/hypr-random-wallpaper.bats.sh
```

### Nix checks

```bash
nix flake check
sudo nixos-rebuild test --flake .#orgm-hyprland
```

### Manual Hyprland checks

```bash
orgm-hypr wallpaper picker-daemon
TIMEFORMAT=%R; time orgm-hypr wallpaper carousel static
pgrep -af 'quickshell .*wallpaper-picker'
hyprctl reload
waybar -c ~/.config/waybar-hypr/config -s ~/.config/waybar-hypr/style.css
```

---

## Work Unit / Commit Plan

1. `feat(hypr): add orgm-hypr skeleton`
2. `feat(hypr): move wallpaper manager to orgm-hypr`
3. `feat(hypr): daemonize wallpaper picker IPC`
4. `feat(hypr): move waybar helpers to orgm-hypr`
5. `feat(hypr): manage dock with orgm-hypr`
6. `feat(hypr): move launch helpers to orgm-hypr`
7. `feat(hypr): move system menus to orgm-hypr`
8. `feat(hypr): move update status to orgm-hypr`
9. `feat(hypr): move remaining helpers to orgm-hypr`
10. `refactor(hypr): route configs through orgm-hypr`

---

## Risks and Guardrails

- **Big-bang rewrite risk:** avoid. Ship one subsystem at a time with wrappers.
- **Hyprland runtime unavailable in dev container:** use fake commands in tests; manual host check required.
- **Waybar output formatting regressions:** snapshot expected JSON/text output before replacing scripts.
- **Process cleanup danger:** always validate command line before killing PIDs.
- **Nix package drift:** add package early and keep wrappers until `orgm-hypr` is installed on host.
- **Dotfiles cross-platform needs:** do not merge `dot.sh` into `orgm-hypr`; consider `orgm-dot` later.

---

## Execution Recommendation

Start with Phase 0 + Phase 1 only. This gives immediate payoff by removing the slow wallpaper shell/Python path without risking menus, Waybar, or dock behavior.

After wallpaper is stable on host for one day, migrate Waybar helpers next because they execute frequently and benefit from Go speed.
