# Wallpaper-Driven Color Theme — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** After each wallpaper set operation, extract a Material You palette via `matugen` and regenerate all orgm-theme component files, preserving the current dark/light mode.

**Architecture:** New `internal/wallpaper/colors.go` adds `ColorSourceImage`, `MapColors`, `ApplyColors`, and `applyColorsQuiet` to the wallpaper package. `Manager` gains `ConfigHome`/`DataHome` fields so `ApplyColors` can call the existing `orgmtheme.BuildWrites`. `SetStatic`/`SetVideo` call `applyColorsQuiet` at their end. New `apply-colors` subcommand exposes the same path from the CLI.

**Tech Stack:** Go 1.23, `github.com/osmargm1202/nixos/internal/orgmtheme`, `matugen` (external binary, env-overridable via `MATUGEN_BIN`), `notify-send` for error notifications.

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `internal/wallpaper/colors.go` | Create | matugen runner, JSON types, MapColors, ColorSourceImage, ApplyColors, applyColorsQuiet |
| `internal/wallpaper/colors_test.go` | Create | unit + integration tests |
| `internal/wallpaper/manager.go` | Modify | add ConfigHome/DataHome fields; hook applyColorsQuiet into SetStatic/SetVideo |
| `cmd/orgm-wallpaper/main.go` | Modify | add `apply-colors` case + flags |

---

### Task 1: Add ConfigHome and DataHome to Manager

**Files:**
- Modify: `internal/wallpaper/manager.go:23-50` (struct) and `:53-88` (NewManager)

- [ ] **Step 1: Add fields to the Manager struct**

In `internal/wallpaper/manager.go`, the `Manager` struct starts at line 23. Add two fields after the existing `Stderr` field:

```go
	Stdout             io.Writer
	Stderr             io.Writer
	ConfigHome         string
	DataHome           string
```

- [ ] **Step 2: Set fields in NewManager**

In `NewManager`, `configHome` is already computed locally (line ~58). Add `dataHome` alongside it and store both:

```go
	home := envDefault("HOME", "")
	runtimeDir := envDefault("XDG_RUNTIME_DIR", "/tmp")
	stateHome := envDefault("XDG_STATE_HOME", filepath.Join(home, ".local/state"))
	stateDir := filepath.Join(stateHome, "hypr-wallpaper")
	configHome := envDefault("XDG_CONFIG_HOME", filepath.Join(home, ".config"))
	dataHome := envDefault("XDG_DATA_HOME", filepath.Join(home, ".local", "share"))
	m := &Manager{
		// ... existing fields unchanged ...
		ConfigHome: configHome,
		DataHome:   dataHome,
	}
```

- [ ] **Step 3: Run existing tests to confirm no regression**

```bash
go test ./internal/wallpaper/... -v 2>&1 | tail -20
```

Expected: all existing tests PASS.

- [ ] **Step 4: Commit**

```bash
git add internal/wallpaper/manager.go
git commit -m "feat(wallpaper): add ConfigHome/DataHome to Manager"
```

---

### Task 2: Create colors.go — matugen runner and JSON types

**Files:**
- Create: `internal/wallpaper/colors.go`
- Create: `internal/wallpaper/colors_test.go`

- [ ] **Step 1: Write the failing test for runMatugen**

Create `internal/wallpaper/colors_test.go`:

```go
package wallpaper

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

// fakeMatugenJSON is a minimal valid matugen --json hex output.
const fakeMatugenJSON = `{
  "colors": {
    "dark": {
      "primary": "#6d9eeb",
      "on_primary": "#002b7c",
      "background": "#1a1c2e",
      "on_background": "#e2e4f6",
      "surface_container": "#252736",
      "surface_container_low": "#1e2030",
      "surface_container_lowest": "#181926",
      "surface_container_high": "#2e3048",
      "surface_container_highest": "#393b54",
      "outline_variant": "#43456a",
      "outline": "#5f6290",
      "on_surface_variant": "#9b9ec7",
      "on_surface": "#c4c6e3",
      "secondary": "#8bd5ca",
      "tertiary": "#c6a0f6",
      "primary_fixed_dim": "#91d7e3",
      "secondary_fixed": "#a6da95",
      "tertiary_fixed": "#eed49f",
      "primary_container": "#3d5f9e",
      "error": "#ed8796",
      "tertiary_container": "#523d6e",
      "on_tertiary_container": "#f4dbd6",
      "on_secondary_container": "#f0c6c6"
    },
    "light": {
      "primary": "#1e66f5",
      "on_primary": "#ffffff",
      "background": "#eff1f5",
      "on_background": "#4c4f69",
      "surface_container": "#e6e9ef",
      "surface_container_low": "#eceef4",
      "surface_container_lowest": "#ffffff",
      "surface_container_high": "#dce0e8",
      "surface_container_highest": "#ccd0da",
      "outline_variant": "#8087a2",
      "outline": "#6c6f85",
      "on_surface_variant": "#5b6078",
      "on_surface": "#4c4f69",
      "secondary": "#179299",
      "tertiary": "#8839ef",
      "primary_fixed_dim": "#0089a0",
      "secondary_fixed": "#40a02b",
      "tertiary_fixed": "#df8e1d",
      "primary_container": "#b7bdf8",
      "error": "#d20f39",
      "tertiary_container": "#ea76cb",
      "on_tertiary_container": "#4c4f69",
      "on_secondary_container": "#cba6f7"
    }
  }
}`

func writeFakeMatugen(t *testing.T, tmpDir string) {
	t.Helper()
	bin := filepath.Join(tmpDir, "matugen")
	script := "#!/bin/sh\nprintf '%s' '" + fakeMatugenJSON + "'\n"
	if err := os.WriteFile(bin, []byte(script), 0o755); err != nil {
		t.Fatalf("write fake matugen: %v", err)
	}
	t.Setenv("MATUGEN_BIN", bin)
}

func TestRunMatugen(t *testing.T) {
	tmp := t.TempDir()
	writeFakeMatugen(t, tmp)

	img := filepath.Join(tmp, "wall.png")
	if err := os.WriteFile(img, []byte("x"), 0o600); err != nil {
		t.Fatal(err)
	}

	out, err := runMatugen(img)
	if err != nil {
		t.Fatalf("runMatugen: %v", err)
	}
	if got := out.Colors.Dark["primary"]; got != "#6d9eeb" {
		t.Errorf("dark primary = %q, want #6d9eeb", got)
	}
	if got := out.Colors.Light["primary"]; got != "#1e66f5" {
		t.Errorf("light primary = %q, want #1e66f5", got)
	}
}
```

- [ ] **Step 2: Run test — expect compile error (colors.go not yet created)**

```bash
go test ./internal/wallpaper/... -run TestRunMatugen -v 2>&1 | head -20
```

Expected: compile error `undefined: runMatugen`.

- [ ] **Step 3: Create colors.go with matugen types and runner**

Create `internal/wallpaper/colors.go`:

```go
package wallpaper

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/osmargm1202/nixos/internal/orgmtheme"
)

// matugenOutput is the top-level JSON structure from `matugen image <path> --json hex`.
type matugenOutput struct {
	Colors struct {
		Dark  map[string]string `json:"dark"`
		Light map[string]string `json:"light"`
	} `json:"colors"`
}

// runMatugen runs matugen on imagePath and returns the parsed color palette.
// The binary is resolved via the MATUGEN_BIN env var, falling back to "matugen".
func runMatugen(imagePath string) (matugenOutput, error) {
	bin := envDefault("MATUGEN_BIN", "matugen")
	out, err := exec.Command(bin, "image", imagePath, "--json", "hex").Output()
	if err != nil {
		return matugenOutput{}, fmt.Errorf("matugen: %w", err)
	}
	var result matugenOutput
	if err := json.Unmarshal(out, &result); err != nil {
		return matugenOutput{}, fmt.Errorf("matugen parse: %w", err)
	}
	return result, nil
}
```

- [ ] **Step 4: Run test — expect PASS**

```bash
go test ./internal/wallpaper/... -run TestRunMatugen -v 2>&1 | tail -10
```

Expected: `PASS`.

- [ ] **Step 5: Commit**

```bash
git add internal/wallpaper/colors.go internal/wallpaper/colors_test.go
git commit -m "feat(wallpaper): add matugen runner and JSON types"
```

---

### Task 3: Add MapColors function

**Files:**
- Modify: `internal/wallpaper/colors.go`
- Modify: `internal/wallpaper/colors_test.go`

- [ ] **Step 1: Write failing tests for MapColors**

Append to `internal/wallpaper/colors_test.go`:

```go
func baseTheme(scheme string) orgmtheme.Theme {
	return orgmtheme.Theme{
		Name:                   "orgm-dark",
		ColorScheme:            scheme,
		GTKTheme:               "Adwaita-dark",
		IconTheme:              "Adwaita",
		CursorTheme:            "Catppuccin-Macchiato-Teal-Cursors",
		CursorSize:             "36",
		QTStyle:                "Darkly",
		PITheme:                "orgm",
		KittyBackgroundOpacity: "0.90",
		// Color fields left as zero — MapColors replaces them all.
	}
}

func parseFakeJSON(t *testing.T) matugenOutput {
	t.Helper()
	var out matugenOutput
	if err := json.Unmarshal([]byte(fakeMatugenJSON), &out); err != nil {
		t.Fatalf("parse fakeMatugenJSON: %v", err)
	}
	return out
}

func TestMapColors_Dark(t *testing.T) {
	out := parseFakeJSON(t)
	result := MapColors(out.Colors.Dark, baseTheme("prefer-dark"))

	// Non-color fields preserved.
	if result.GTKTheme != "Adwaita-dark" {
		t.Errorf("GTKTheme = %q, want Adwaita-dark", result.GTKTheme)
	}

	// Accent from primary (strip leading #).
	if result.Blue != "6d9eeb" {
		t.Errorf("Blue = %q, want 6d9eeb", result.Blue)
	}
	// Base from background.
	if result.Base != "1a1c2e" {
		t.Errorf("Base = %q, want 1a1c2e", result.Base)
	}
	// Text from on_background.
	if result.Text != "e2e4f6" {
		t.Errorf("Text = %q, want e2e4f6", result.Text)
	}
	// Red from error.
	if result.Red != "ed8796" {
		t.Errorf("Red = %q, want ed8796", result.Red)
	}
	// PanelBG: dark scheme → base + "99".
	if result.PanelBG != "1a1c2e99" {
		t.Errorf("PanelBG = %q, want 1a1c2e99", result.PanelBG)
	}
	// QSCard: "22" + surface_container.
	if result.QSCard != "22252736" {
		t.Errorf("QSCard = %q, want 22252736", result.QSCard)
	}
}

func TestMapColors_Light(t *testing.T) {
	out := parseFakeJSON(t)
	result := MapColors(out.Colors.Light, baseTheme("prefer-light"))

	if result.Blue != "1e66f5" {
		t.Errorf("Blue = %q, want 1e66f5", result.Blue)
	}
	// PanelBG: light scheme → base + "dd".
	if result.PanelBG != "eff1f5dd" {
		t.Errorf("PanelBG = %q, want eff1f5dd", result.PanelBG)
	}
	// MenuBG: light scheme → base + "ee".
	if result.MenuBG != "eff1f5ee" {
		t.Errorf("MenuBG = %q, want eff1f5ee", result.MenuBG)
	}
}
```

- [ ] **Step 2: Run — expect compile error (MapColors undefined)**

```bash
go test ./internal/wallpaper/... -run TestMapColors -v 2>&1 | head -10
```

Expected: compile error `undefined: MapColors`.

- [ ] **Step 3: Implement MapColors in colors.go**

Add after `runMatugen`:

```go
// MapColors replaces all color fields in base with values from a matugen palette.
// Non-color identity fields (GTKTheme, IconTheme, CursorTheme, etc.) are preserved.
func MapColors(palette map[string]string, base orgmtheme.Theme) orgmtheme.Theme {
	t := base
	get := func(key string) string { return strings.TrimPrefix(palette[key], "#") }

	bgHex := get("background")
	sc := get("surface_container")

	t.Base     = bgHex
	t.Mantle   = get("surface_container_low")
	t.Crust    = get("surface_container_lowest")
	t.Surface0 = sc
	t.Surface1 = get("surface_container_high")
	t.Surface2 = get("surface_container_highest")
	t.Overlay0 = get("outline_variant")
	t.Overlay1 = get("outline")
	t.Overlay2 = get("on_surface_variant")
	t.Text     = get("on_background")
	t.Subtext0 = get("on_surface_variant")
	t.Subtext1 = get("on_surface")
	t.Blue     = get("primary")
	t.Mauve    = get("tertiary")
	t.Teal     = get("secondary")
	t.Sky      = get("primary_fixed_dim")
	t.Green    = get("secondary_fixed")
	t.Yellow   = get("tertiary_fixed")
	t.Peach    = get("primary_container")
	t.Red      = get("error")
	t.Pink     = get("tertiary_container")
	t.Rosewater = get("on_tertiary_container")
	t.OnAccent = get("on_primary")

	if base.ColorScheme == "prefer-light" {
		t.PanelBG = bgHex + "dd"
		t.MenuBG  = bgHex + "ee"
	} else {
		t.PanelBG = bgHex + "99"
		t.MenuBG  = bgHex + "dd"
	}

	t.QSOverlay    = bgHex
	t.QSCard       = "22" + sc
	t.QSCardStrong = "33" + get("surface_container_high")
	t.QSCardSoft   = "1e" + sc
	t.QSEvent      = "2b" + sc
	t.QSHover      = "55" + sc

	return t
}
```

- [ ] **Step 4: Run tests — expect PASS**

```bash
go test ./internal/wallpaper/... -run TestMapColors -v 2>&1 | tail -10
```

Expected: both `TestMapColors_Dark` and `TestMapColors_Light` PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/wallpaper/colors.go internal/wallpaper/colors_test.go
git commit -m "feat(wallpaper): add MapColors — matugen palette to orgm Theme"
```

---

### Task 4: Add ColorSourceImage method

**Files:**
- Modify: `internal/wallpaper/colors.go`
- Modify: `internal/wallpaper/colors_test.go`

- [ ] **Step 1: Write failing tests for ColorSourceImage**

Append to `internal/wallpaper/colors_test.go`:

```go
func newTestManager(t *testing.T) (*Manager, string) {
	t.Helper()
	tmp := t.TempDir()
	m := NewManager(os.Stdout, os.Stderr)
	m.StateDir = filepath.Join(tmp, "state")
	m.StateFile = filepath.Join(m.StateDir, "state")
	if err := os.MkdirAll(m.StateDir, 0o755); err != nil {
		t.Fatal(err)
	}
	return m, tmp
}

func TestColorSourceImage_Static(t *testing.T) {
	m, tmp := newTestManager(t)
	wallpaper := filepath.Join(tmp, "wall.png")
	if err := os.WriteFile(wallpaper, []byte("x"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(m.StateFile, []byte("mode=static\npath="+wallpaper+"\n"), 0o600); err != nil {
		t.Fatal(err)
	}

	got, err := m.ColorSourceImage()
	if err != nil {
		t.Fatalf("ColorSourceImage: %v", err)
	}
	if got != wallpaper {
		t.Errorf("got %q, want %q", got, wallpaper)
	}
}

func TestColorSourceImage_Video_ThumbExists(t *testing.T) {
	m, tmp := newTestManager(t)
	video := filepath.Join(tmp, "Videos", "wallpapers", "city.mp4")
	if err := os.MkdirAll(filepath.Dir(video), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(video, []byte("x"), 0o600); err != nil {
		t.Fatal(err)
	}
	// Pre-create thumb so ffmpeg is never called.
	thumb := filepath.Join(filepath.Dir(video), ".thumb", "city.mp4.jpg")
	if err := os.MkdirAll(filepath.Dir(thumb), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(thumb, []byte("fake-jpeg-data"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(m.StateFile, []byte("mode=video\npath="+video+"\n"), 0o600); err != nil {
		t.Fatal(err)
	}

	got, err := m.ColorSourceImage()
	if err != nil {
		t.Fatalf("ColorSourceImage: %v", err)
	}
	if got != thumb {
		t.Errorf("got %q, want %q", got, thumb)
	}
}

func TestColorSourceImage_NoWallpaper(t *testing.T) {
	m, _ := newTestManager(t)
	// StateFile does not exist → no wallpaper set.

	_, err := m.ColorSourceImage()
	if err == nil {
		t.Error("expected error when no wallpaper set, got nil")
	}
}
```

- [ ] **Step 2: Run — expect compile error (ColorSourceImage undefined)**

```bash
go test ./internal/wallpaper/... -run TestColorSourceImage -v 2>&1 | head -10
```

Expected: compile error.

- [ ] **Step 3: Implement ColorSourceImage in colors.go**

Add after `MapColors`:

```go
// ColorSourceImage returns the image path to use for color extraction.
// For video wallpapers, it returns the thumbnail generated by WallpaperThumb.
// Returns an error if no wallpaper is currently set.
func (m *Manager) ColorSourceImage() (string, error) {
	mode := m.CurrentMode()
	path := m.StateValue("path")
	if path == "" {
		return "", fmt.Errorf("no wallpaper set")
	}
	if strings.Contains(mode, "video") {
		return m.WallpaperThumb(path)
	}
	return path, nil
}
```

- [ ] **Step 4: Run tests — expect PASS**

```bash
go test ./internal/wallpaper/... -run TestColorSourceImage -v 2>&1 | tail -10
```

Expected: all three `TestColorSourceImage_*` PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/wallpaper/colors.go internal/wallpaper/colors_test.go
git commit -m "feat(wallpaper): add ColorSourceImage — static path or video thumb"
```

---

### Task 5: Add ApplyColors and applyColorsQuiet

**Files:**
- Modify: `internal/wallpaper/colors.go`
- Modify: `internal/wallpaper/colors_test.go`

- [ ] **Step 1: Write failing test for ApplyColors dry-run**

Append to `internal/wallpaper/colors_test.go`:

```go
func writeThemeEnv(t *testing.T, dir, name string) {
	t.Helper()
	themesDir := filepath.Join(dir, "orgm-theme", "themes")
	if err := os.MkdirAll(themesDir, 0o755); err != nil {
		t.Fatal(err)
	}
	content := `# test theme
THEME_NAME=` + name + `
COLOR_SCHEME=prefer-dark
GTK_THEME=Adwaita-dark
ICON_THEME=Adwaita
CURSOR_THEME=Catppuccin-Macchiato-Teal-Cursors
CURSOR_SIZE=36
QT_STYLE=Darkly
PI_THEME=orgm
KITTY_BACKGROUND_OPACITY=0.90
BASE=24273a
MANTLE=1e2030
CRUST=181926
TEXT=cad3f5
SUBTEXT0=a5adcb
SUBTEXT1=b8c0e0
SURFACE0=363a4f
SURFACE1=494d64
SURFACE2=5b6078
OVERLAY0=6e738d
OVERLAY1=8087a2
OVERLAY2=939ab7
BLUE=8aadf4
GREEN=a6da95
YELLOW=eed49f
PEACH=f5a97f
RED=ed8796
MAUVE=c6a0f6
PINK=f5bde6
TEAL=8bd5ca
SKY=91d7e3
ROSEWATER=f4dbd6
PANEL_BG=00000099
MENU_BG=000000dd
QS_OVERLAY=000000
QS_CARD=22363a4f
QS_CARD_STRONG=33494d64
QS_CARD_SOFT=1e363a4f
QS_EVENT=2b363a4f
QS_HOVER=55363a4f
ON_ACCENT=11111b
`
	if err := os.WriteFile(filepath.Join(themesDir, name+".env"), []byte(content), 0o600); err != nil {
		t.Fatal(err)
	}
}

func TestApplyColors_DryRun(t *testing.T) {
	tmp := t.TempDir()
	writeFakeMatugen(t, tmp)

	// Set up wallpaper image.
	wallpaper := filepath.Join(tmp, "wall.png")
	if err := os.WriteFile(wallpaper, []byte("x"), 0o600); err != nil {
		t.Fatal(err)
	}

	// Set up manager with temp dirs.
	m, _ := newTestManager(t)
	m.StateHome = filepath.Join(tmp, "state")
	m.ConfigHome = filepath.Join(tmp, "config")
	m.DataHome = filepath.Join(tmp, "data")

	// Write current theme state.
	themeStateDir := filepath.Join(m.StateHome, "orgm-theme")
	if err := os.MkdirAll(themeStateDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(themeStateDir, "current"), []byte("orgm-dark\n"), 0o600); err != nil {
		t.Fatal(err)
	}

	// Write theme .env file.
	writeThemeEnv(t, m.ConfigHome, "orgm-dark")

	// Write wallpaper state.
	if err := os.MkdirAll(m.StateDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(m.StateFile, []byte("mode=static\npath="+wallpaper+"\n"), 0o600); err != nil {
		t.Fatal(err)
	}

	// Capture stdout.
	r, w, _ := os.Pipe()
	m.Stdout = w

	err := m.ApplyColors(ApplyColorsOptions{DryRun: true})
	w.Close()
	if err != nil {
		t.Fatalf("ApplyColors dry-run: %v", err)
	}

	buf := make([]byte, 4096)
	n, _ := r.Read(buf)
	output := string(buf[:n])

	// Dry-run should list at least the waybar and kitty write paths.
	if !strings.Contains(output, "waybar") {
		t.Errorf("dry-run output missing waybar path: %s", output)
	}
	if !strings.Contains(output, "kitty") {
		t.Errorf("dry-run output missing kitty path: %s", output)
	}
}
```

- [ ] **Step 2: Run — expect compile error (ApplyColors undefined)**

```bash
go test ./internal/wallpaper/... -run TestApplyColors -v 2>&1 | head -10
```

Expected: compile error.

- [ ] **Step 3: Implement ApplyColors and applyColorsQuiet in colors.go**

Add after `ColorSourceImage`:

```go
// ApplyColorsOptions controls ApplyColors behaviour.
type ApplyColorsOptions struct {
	NoReload bool
	DryRun   bool
}

// ApplyColors extracts a color palette from the active wallpaper via matugen,
// maps it onto the current orgm theme, and regenerates all themed component files.
func (m *Manager) ApplyColors(opts ApplyColorsOptions) error {
	src, err := m.ColorSourceImage()
	if err != nil {
		return fmt.Errorf("source image: %w", err)
	}

	matout, err := runMatugen(src)
	if err != nil {
		return err
	}

	themeName := readTrim(filepath.Join(m.StateHome, "orgm-theme", "current"))
	if themeName == "" {
		themeName = "orgm-dark"
	}
	themesDir := filepath.Join(m.ConfigHome, "orgm-theme", "themes")
	base, err := orgmtheme.LoadTheme(themesDir, themeName)
	if err != nil {
		return fmt.Errorf("load theme: %w", err)
	}

	var palette map[string]string
	if base.ColorScheme == "prefer-light" {
		palette = matout.Colors.Light
	} else {
		palette = matout.Colors.Dark
	}

	theme := MapColors(palette, base)
	env := orgmtheme.Env{ConfigHome: m.ConfigHome, DataHome: m.DataHome}
	writes, err := orgmtheme.BuildWrites(env, theme)
	if err != nil {
		return fmt.Errorf("build writes: %w", err)
	}

	if opts.DryRun {
		for _, w := range writes {
			fmt.Fprintf(m.Stdout, "write %s\n", w.Path)
		}
		return nil
	}

	for _, w := range writes {
		if err := os.MkdirAll(filepath.Dir(w.Path), 0o755); err != nil {
			return fmt.Errorf("mkdir %s: %w", filepath.Dir(w.Path), err)
		}
		if err := os.WriteFile(w.Path, []byte(w.Content), 0o644); err != nil {
			return fmt.Errorf("write %s: %w", w.Path, err)
		}
	}

	if !opts.NoReload {
		_ = exec.Command("pkill", "-SIGUSR2", "waybar").Run()
		_ = exec.Command("swaync-client", "-rs").Run()
	}
	return nil
}

// applyColorsQuiet runs ApplyColors and, on error, logs to stderr and sends a
// desktop notification instead of returning the error to the caller.
func (m *Manager) applyColorsQuiet() {
	if err := m.ApplyColors(ApplyColorsOptions{}); err != nil {
		msg := "Color extraction failed: " + err.Error()
		fmt.Fprintln(m.Stderr, "orgm-wallpaper: "+msg)
		_ = exec.Command("notify-send", "-u", "normal", "orgm-wallpaper", msg).Run()
	}
}
```

- [ ] **Step 4: Run test — expect PASS**

```bash
go test ./internal/wallpaper/... -run TestApplyColors -v 2>&1 | tail -10
```

Expected: `TestApplyColors_DryRun` PASS.

- [ ] **Step 5: Run all wallpaper tests**

```bash
go test ./internal/wallpaper/... -v 2>&1 | tail -20
```

Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add internal/wallpaper/colors.go internal/wallpaper/colors_test.go
git commit -m "feat(wallpaper): add ApplyColors and applyColorsQuiet"
```

---

### Task 6: Hook applyColorsQuiet into SetStatic and SetVideo

**Files:**
- Modify: `internal/wallpaper/manager.go:636-656` (SetStatic), `:802-816` (SetVideo)

- [ ] **Step 1: Add applyColorsQuiet call at end of SetStatic**

`SetStatic` currently ends (line 655) with:
```go
	return m.WriteState(mode, path)
```

Replace with:
```go
	if err := m.WriteState(mode, path); err != nil {
		return err
	}
	m.applyColorsQuiet()
	return nil
```

- [ ] **Step 2: Add applyColorsQuiet call at end of SetVideo**

`SetVideo` currently ends (line 815) with:
```go
	return m.WriteState("video", path)
```

Replace with:
```go
	if err := m.WriteState("video", path); err != nil {
		return err
	}
	m.applyColorsQuiet()
	return nil
```

- [ ] **Step 3: Run all tests**

```bash
go test ./... 2>&1 | tail -20
```

Expected: all PASS. (applyColorsQuiet in tests will fail silently — matugen won't be found, notify-send will be a no-op, but the wallpaper operation still succeeds.)

- [ ] **Step 4: Build to confirm compilation**

```bash
go build ./... 2>&1
```

Expected: no output (clean build).

- [ ] **Step 5: Commit**

```bash
git add internal/wallpaper/manager.go
git commit -m "feat(wallpaper): trigger color extraction after set-static and set-video"
```

---

### Task 7: Add apply-colors subcommand to CLI

**Files:**
- Modify: `cmd/orgm-wallpaper/main.go`

- [ ] **Step 1: Add the case to the switch in runWithIO**

In `cmd/orgm-wallpaper/main.go`, locate the `switch args[0]` block. Add a new case before `default`:

```go
	case "apply-colors":
		flags := flag.NewFlagSet("orgm-wallpaper apply-colors", flag.ContinueOnError)
		flags.SetOutput(stderr)
		noReload := flags.Bool("no-reload", false, "write files but skip waybar reload")
		dryRun := flags.Bool("dry-run", false, "print planned writes without executing")
		if err := flags.Parse(args[1:]); err != nil {
			return cli.UsageError(err.Error())
		}
		if flags.NArg() != 0 {
			return cli.UsageError("unexpected argument: %s", flags.Arg(0))
		}
		return m.ApplyColors(wallpaper.ApplyColorsOptions{NoReload: *noReload, DryRun: *dryRun})
```

- [ ] **Step 2: Update the usage() string**

Find the `usage()` function at the bottom of `main.go`. Replace:
```go
	return "usage: orgm-wallpaper [data|status|clean-thumbs|restore|set-static|set-video|random|random-static|random-video|warm-page|pick|picker-daemon|daemon]"
```
With:
```go
	return "usage: orgm-wallpaper [data|status|clean-thumbs|restore|set-static|set-video|random|random-static|random-video|warm-page|pick|picker-daemon|daemon|apply-colors]"
```

- [ ] **Step 3: Build**

```bash
go build ./cmd/orgm-wallpaper/... 2>&1
```

Expected: no output.

- [ ] **Step 4: Smoke test dry-run (requires a wallpaper to be set)**

```bash
orgm-wallpaper apply-colors --dry-run 2>&1 | head -10
```

Expected: list of `write <path>` lines if a wallpaper is active, or an error message if no wallpaper is set. Either is valid at this stage.

- [ ] **Step 5: Run all tests one final time**

```bash
go test ./... 2>&1 | tail -20
```

Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add cmd/orgm-wallpaper/main.go
git commit -m "feat(wallpaper): add apply-colors subcommand with --no-reload and --dry-run"
```

---

## Self-Review

**Spec coverage:**
- ✅ Static wallpaper → image used directly (`ColorSourceImage` static branch)
- ✅ Video wallpaper → thumbnail via `WallpaperThumb` (`ColorSourceImage` video branch)
- ✅ matugen as extraction tool (`runMatugen`)
- ✅ dark/light preserved (`ColorScheme` drives palette selection)
- ✅ All orgm-themes components updated (`BuildWrites` call unchanged)
- ✅ Failure → `notify-send` + stderr (`applyColorsQuiet`)
- ✅ Silent when no wallpaper (`ColorSourceImage` empty path → error → notify)
- ✅ Integrated in Go (`colors.go` in wallpaper package)
- ✅ Triggers on `set-static`/`set-video` (Task 6 hooks)
- ✅ Standalone `apply-colors` subcommand (Task 7)
- ✅ `--no-reload` and `--dry-run` flags (Task 7)
- ✅ `MATUGEN_BIN` env override for testing

**Placeholder scan:** No TBDs. All code steps are complete.

**Type consistency:**
- `ApplyColorsOptions` defined in Task 5, used in Task 7 ✅
- `MapColors(palette map[string]string, base orgmtheme.Theme) orgmtheme.Theme` consistent across Tasks 3 and 5 ✅
- `m.ConfigHome` / `m.DataHome` added in Task 1, used in Task 5 ✅
- `writeFakeMatugen` helper defined in Task 2, reused in Task 5 ✅
- `newTestManager` helper defined in Task 4, reused in Task 5 ✅
