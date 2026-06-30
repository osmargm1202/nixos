# orgm-themes Go Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `orgm-themes`, a fast Go replacement for Bash `orgm-theme`, while keeping current dark/light files and commands compatible.

**Architecture:** Add focused package `internal/orgmtheme` for loading env themes, rendering active config files, writing atomically, wallpaper theme memory, and reload planning. Add `cmd/orgm-themes` CLI. Convert `config/shared/.local/bin/orgm-theme` into compatibility wrapper that execs `orgm-themes`.

**Tech Stack:** Go 1.23, Bash smoke tests, dotfiles managed by `orgm-dot`, NixOS packaging in `/home/osmarg/Hobby/nixos`.

---

## File map

- Create: `internal/orgmtheme/theme.go` — env theme loader and typed palette/settings.
- Create: `internal/orgmtheme/render.go` — render active files matching current Bash helper.
- Create: `internal/orgmtheme/apply.go` — apply orchestration, state writes, wallpaper memory, reload planning.
- Create: `internal/orgmtheme/writer.go` — atomic writer and file helpers.
- Create: `internal/orgmtheme/theme_test.go` — loader/status/toggle tests.
- Create: `internal/orgmtheme/render_test.go` — generated file snapshot-style assertions.
- Create: `internal/orgmtheme/apply_test.go` — apply/wallpaper/reload tests.
- Create: `cmd/orgm-themes/main.go` — CLI.
- Create: `cmd/orgm-themes/main_test.go` — CLI tests.
- Modify: `config/shared/.local/bin/orgm-theme` — wrapper to `orgm-themes`, fallback error if missing.
- Modify: `config/dotfiles.json` — keep wrapper tracked; no manifest change if path already exists.
- Later in NixOS repo: create `nixos/packages/orgm-themes.nix`; modify `nixos/profiles/hyprland.nix` and `flake.nix` package exports.

## Task 1: Theme loader and CLI skeleton

**Files:**
- Create: `internal/orgmtheme/theme.go`
- Create: `internal/orgmtheme/theme_test.go`
- Create: `cmd/orgm-themes/main.go`
- Create: `cmd/orgm-themes/main_test.go`

- [ ] **Step 1: Write failing loader tests**

Create `internal/orgmtheme/theme_test.go`:

```go
package orgmtheme

import (
	"os"
	"path/filepath"
	"testing"
)

func writeTestTheme(t *testing.T, dir, name string) {
	t.Helper()
	content := `THEME_NAME=` + name + `
COLOR_SCHEME=prefer-light
GTK_THEME=Adwaita
ICON_THEME=Adwaita
CURSOR_THEME=Catppuccin-Latte-Teal-Cursors
CURSOR_SIZE=36
QT_STYLE=Fusion
PI_THEME=orgm-light
KITTY_BACKGROUND_OPACITY=1.0
BASE=ffffff
MANTLE=f8fafc
CRUST=e5e7eb
TEXT=111827
SUBTEXT0=1f2937
SUBTEXT1=111827
SURFACE0=d1d5db
SURFACE1=9ca3af
SURFACE2=6b7280
OVERLAY0=374151
OVERLAY1=1f2937
OVERLAY2=111827
BLUE=0057d9
GREEN=40a02b
YELLOW=df8e1d
PEACH=fe640b
RED=d20f39
MAUVE=8839ef
PINK=ea76cb
TEAL=179299
SKY=04a5e5
ROSEWATER=dc8a78
PANEL_BG=ffffffff
MENU_BG=ffffffff
QS_OVERLAY=ffffffff
QS_CARD=e5e7ebff
QS_CARD_STRONG=bfdbfeff
QS_CARD_SOFT=f8fafcff
QS_EVENT=ffffffff
QS_HOVER=93c5fdff
ON_ACCENT=ffffff
`
	if err := os.WriteFile(filepath.Join(dir, name+".env"), []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
}

func TestLoadThemeEnv(t *testing.T) {
	dir := t.TempDir()
	writeTestTheme(t, dir, "orgm-light")
	theme, err := LoadTheme(dir, "orgm-light")
	if err != nil {
		t.Fatalf("LoadTheme error = %v", err)
	}
	if theme.Name != "orgm-light" || theme.Text != "111827" || theme.Blue != "0057d9" {
		t.Fatalf("theme = %#v", theme)
	}
}

func TestLoadThemeMissingRequiredKey(t *testing.T) {
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, "bad.env"), []byte("THEME_NAME=bad\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	_, err := LoadTheme(dir, "bad")
	if err == nil {
		t.Fatal("LoadTheme succeeded, want required key error")
	}
}
```

- [ ] **Step 2: Run failing loader test**

Run:

```bash
go test ./internal/orgmtheme -run 'TestLoadTheme' -count=1
```

Expected: FAIL because package does not exist.

- [ ] **Step 3: Implement loader**

Create `internal/orgmtheme/theme.go` with typed `Theme`, `LoadTheme(themesDir, name string) (Theme, error)`, and `ListThemes(themesDir string) ([]string, error)`. Parse `KEY=value` lines without shell evaluation. Reject missing required keys. Keep values without leading `#`, matching existing env files.

- [ ] **Step 4: Add CLI tests**

Create `cmd/orgm-themes/main_test.go` with tests for `list`, `current`, and missing args using `runWithIO(args, stdout, stderr, env)`.

- [ ] **Step 5: Implement CLI skeleton**

Create `cmd/orgm-themes/main.go` with commands `list`, `current`, `status`, `apply`, `toggle`. At this task, only `list/current/status` need full behavior; `apply/toggle` may call package stubs returning clear usage errors until Task 3.

- [ ] **Step 6: Verify**

Run:

```bash
go test ./internal/orgmtheme ./cmd/orgm-themes -count=1
```

Expected: PASS.

## Task 2: Render active files exactly enough for current tests

**Files:**
- Create: `internal/orgmtheme/render.go`
- Create: `internal/orgmtheme/render_test.go`

- [ ] **Step 1: Write failing render tests**

Create tests that load `orgm-light` fixture and assert rendered outputs contain:

```text
waybar orgm-current.css: @define-color text     #111827;
waybar orgm-current.css: @define-color panel_bg rgba(255, 255, 255, 1);
gtk-4.0/gtk.css: @define-color window_fg_color #111827;
kitty/current-theme.conf: background_opacity 1.0
hypr/scheme/current.conf: $background = ffffff
quickshell/theme/theme.json: "accent": "#0057d9"
```

- [ ] **Step 2: Run failing render test**

Run:

```bash
go test ./internal/orgmtheme -run 'TestRender' -count=1
```

Expected: FAIL because renderers do not exist.

- [ ] **Step 3: Implement renderers**

Implement `BuildWrites(env Env, theme Theme) ([]PlannedWrite, error)` producing same active paths as Bash helper. Include helpers `cssColor(hex string) string` and `hexToRGB` equivalent. Use generated marker comments where compatible, but do not change file names.

- [ ] **Step 4: Verify renderers**

Run:

```bash
go test ./internal/orgmtheme -run 'TestRender' -count=1
```

Expected: PASS.

## Task 3: Apply, atomic writes, wallpaper memory

**Files:**
- Create: `internal/orgmtheme/writer.go`
- Create: `internal/orgmtheme/apply.go`
- Create: `internal/orgmtheme/apply_test.go`
- Modify: `cmd/orgm-themes/main.go`

- [ ] **Step 1: Write failing apply tests**

Tests must assert:

```go
// apply writes current + current.env
// apply saves outgoing wallpaper from state/hypr-wallpaper/state
// apply saves monitor wallpapers from state/hypr-wallpaper/monitors/*.state
// apply restores incoming wallpaper after writes via planned command orgm-wallpaper set-static PATH --monitor OUTPUT
// --no-reload produces no live reload commands
```

- [ ] **Step 2: Run failing apply test**

Run:

```bash
go test ./internal/orgmtheme -run 'TestApply' -count=1
```

Expected: FAIL because apply does not exist.

- [ ] **Step 3: Implement atomic writer and apply**

Implement:

```go
type ApplyOptions struct {
	ThemeName string
	NoReload bool
	DryRun bool
	PrintReload bool
	Env Env
	Runner CommandRunner
}
```

Use temp file in same directory + rename. For `~/.pi/agent/settings.json`, update JSON only if file exists; do not require Python.

- [ ] **Step 4: Wire CLI apply/toggle**

`orgm-themes apply orgm-light --no-reload` applies files only. `toggle` reads current, flips `orgm-light`/`orgm-dark`, then applies.

- [ ] **Step 5: Verify apply tests**

Run:

```bash
go test ./internal/orgmtheme ./cmd/orgm-themes -count=1
```

Expected: PASS.

## Task 4: Compatibility wrapper and shell smoke tests

**Files:**
- Modify: `config/shared/.local/bin/orgm-theme`
- Test: `tests/helpers/orgm-theme-light-contrast.bats.sh`
- Test: `tests/helpers/orgm-theme-wallpaper.bats.sh`

- [ ] **Step 1: Build local binary for smoke tests**

Run:

```bash
go build -o /tmp/orgm-themes ./cmd/orgm-themes
```

Expected: PASS.

- [ ] **Step 2: Replace Bash helper with wrapper**

Replace `config/shared/.local/bin/orgm-theme` with:

```bash
#!/usr/bin/env bash
set -euo pipefail

if command -v orgm-themes >/dev/null 2>&1; then
  exec orgm-themes "$@"
fi

if [ -x "$HOME/go/bin/orgm-themes" ]; then
  exec "$HOME/go/bin/orgm-themes" "$@"
fi

echo "orgm-theme: orgm-themes not found in PATH" >&2
exit 127
```

- [ ] **Step 3: Run smoke tests with PATH override**

Run:

```bash
mkdir -p /tmp/orgm-themes-bin
cp /tmp/orgm-themes /tmp/orgm-themes-bin/orgm-themes
PATH="/tmp/orgm-themes-bin:$PATH" bash tests/helpers/orgm-theme-light-contrast.bats.sh
PATH="/tmp/orgm-themes-bin:$PATH" bash tests/helpers/orgm-theme-wallpaper.bats.sh
```

Expected: both PASS.

- [ ] **Step 4: Verify full Go tests**

Run:

```bash
go test ./...
```

Expected: PASS.

## Task 5: Package in NixOS repo

**Files in `/home/osmarg/Hobby/nixos`:**
- Create: `nixos/packages/orgm-themes.nix`
- Modify: `nixos/profiles/hyprland.nix`
- Modify: `flake.nix`

- [ ] **Step 1: Create package file**

Use same filtered source pattern as `nixos/packages/orgm-wallpaper.nix`, with:

```nix
buildGoModule {
  pname = "orgm-themes";
  version = "0.1.0";
  src = filteredSource;
  subPackages = [ "cmd/orgm-themes" ];
  vendorHash = null;
  meta.mainProgram = "orgm-themes";
}
```

- [ ] **Step 2: Wire package into Hyprland profile**

Add `orgmThemes = pkgs.callPackage ../packages/orgm-themes.nix { inherit dotfilesOrgmSource; };` and include `orgmThemes` in `environment.systemPackages` near `orgmWallpaper`.

- [ ] **Step 3: Export flake package**

Add `orgmThemes` package binding and expose package key `"orgm-themes" = orgmThemes;` in `/home/osmarg/Hobby/nixos/flake.nix`.

- [ ] **Step 4: Verify package eval/build if practical**

Run from `/home/osmarg/Hobby/nixos`:

```bash
nix build .#orgm-themes
```

Expected: binary builds.

## Task 6: Final verification and sync review

**Files:**
- All above.

- [ ] **Step 1: Run all relevant tests**

Run from dotfiles worktree:

```bash
go test ./...
bash tests/helpers/orgm-theme-light-contrast.bats.sh
bash tests/helpers/orgm-theme-wallpaper.bats.sh
```

Expected: PASS.

- [ ] **Step 2: Check managed dotfile diff**

Run from normal dotfiles checkout or via host as required:

```bash
distrobox-host-exec orgm-dot diff
```

Expected: only intended wrapper and generated source changes appear.

- [ ] **Step 3: Manual timing check**

Run:

```bash
time orgm-themes apply orgm-light --no-reload
time orgm-themes apply orgm-dark --no-reload
```

Expected: apply-only path completes much faster than old Bash helper and does not scan `/nix/store`.

- [ ] **Step 4: Commit work units**

Suggested commits:

```bash
git add docs/superpowers/specs/2026-06-02-orgm-themes-go-design.md docs/superpowers/plans/2026-06-02-orgm-themes-go.md
git commit -m "docs: plan orgm-themes go helper"

git add internal/orgmtheme cmd/orgm-themes config/shared/.local/bin/orgm-theme
git commit -m "feat: add orgm-themes go helper"
```

Commit NixOS packaging separately in `/home/osmarg/Hobby/nixos`.
