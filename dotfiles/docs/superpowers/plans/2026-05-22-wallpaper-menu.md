# Wallpaper Menu Unificado Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the fuzzel/rofi wallpaper choice flow with one Quickshell wallpaper menu that has NORMAL and LIVE tabs plus a tab-aware Random button launched directly from Waybar.

**Architecture:** Extend `internal/wallpaper` data generation with a combined dual-tab schema while keeping existing single-mode schema for `carousel static/video`. Change `orgm-hypr wallpaper pick` to generate combined data and show Quickshell directly. Update the QML picker to select between per-mode datasets in one panel and update Waybar to call `wallpaper pick`.

**Tech Stack:** Go (`orgm-hypr` CLI and tests), QML/Quickshell, Waybar JSONC config, `orgm-dot` for final sync.

---

## Files and responsibilities

- `internal/wallpaper/data.go` — owns JSON schema builders for single-mode and dual-mode picker data.
- `internal/wallpaper/data_test.go` — unit tests for picker schemas and JSON output.
- `internal/wallpaper/manager.go` — owns filesystem/state generation, random/apply actions, and Quickshell launch flow.
- `cmd/orgm-hypr/main.go` — parses `orgm-hypr wallpaper ...` subcommands.
- `cmd/orgm-hypr/main_test.go` — CLI-level usage tests if needed.
- `config/shared/.config/quickshell/wallpaper-picker/shell.qml` — renders the resident wallpaper picker UI.
- `config/shared/.config/waybar-hypr/config` — launches wallpaper picker from Waybar.
- `docs/superpowers/specs/2026-05-22-wallpaper-menu-design.md` — source design spec already committed in `b5bd4f5`.

---

### Task 1: Add dual picker schema tests

**Files:**
- Modify: `internal/wallpaper/data_test.go`
- Modify: `internal/wallpaper/data.go`

- [ ] **Step 1: Write failing tests for dual picker data**

Append these tests to `internal/wallpaper/data_test.go` before `TestCleanStaleThumbnailsRemovesOnlyMissingSources`:

```go
func TestBuildCombinedPickerDataIncludesNormalAndLiveTabs(t *testing.T) {
	manifest := strings.NewReader(strings.Join([]string{
		"static\t/home/test/Pictures/Wallpapers/a.png",
		"video\t/home/test/Videos/wallpapers/live.mp4",
		"static\t/home/test/Pictures/Wallpapers/b.jpg",
	}, "\n"))

	data, err := BuildCombinedPickerData(CombinedDataOptions{
		ManifestPath: "manifest.tsv",
		JSONPath:    "picker.json",
		InitialMode: "video",
		CurrentMode: "video",
		CurrentPath: "/home/test/Videos/wallpapers/live.mp4",
		Script:      "orgm-hypr",
		ScriptArgs:  []string{"wallpaper"},
	}, manifest)
	if err != nil {
		t.Fatalf("BuildCombinedPickerData failed: %v", err)
	}

	if data.Mode != "combined" {
		t.Fatalf("mode = %q, want combined", data.Mode)
	}
	if data.InitialMode != "video" {
		t.Fatalf("initialMode = %q, want video", data.InitialMode)
	}
	if data.Script != "orgm-hypr" {
		t.Fatalf("script = %q, want orgm-hypr", data.Script)
	}
	if strings.Join(data.ScriptArgs, "\x00") != "wallpaper" {
		t.Fatalf("scriptArgs = %#v, want [wallpaper]", data.ScriptArgs)
	}

	staticTab := data.Tabs["static"]
	if staticTab.Title != "Normal wallpapers" {
		t.Fatalf("static title = %q", staticTab.Title)
	}
	if staticTab.ApplyCommand != "set-static" {
		t.Fatalf("static apply = %q", staticTab.ApplyCommand)
	}
	if staticTab.RandomCommand != "random-static" {
		t.Fatalf("static random = %q", staticTab.RandomCommand)
	}
	if staticTab.Current != "" {
		t.Fatalf("static current = %q, want empty when current mode is video", staticTab.Current)
	}
	if len(staticTab.Items) != 2 {
		t.Fatalf("static item count = %d, want 2", len(staticTab.Items))
	}
	if staticTab.Items[0].Thumb != "/home/test/Pictures/Wallpapers/.thumb/a.png.jpg" {
		t.Fatalf("static first thumb = %q", staticTab.Items[0].Thumb)
	}

	videoTab := data.Tabs["video"]
	if videoTab.Title != "Live wallpapers" {
		t.Fatalf("video title = %q", videoTab.Title)
	}
	if videoTab.ApplyCommand != "set-video" {
		t.Fatalf("video apply = %q", videoTab.ApplyCommand)
	}
	if videoTab.RandomCommand != "random-video" {
		t.Fatalf("video random = %q", videoTab.RandomCommand)
	}
	if videoTab.Current != "/home/test/Videos/wallpapers/live.mp4" {
		t.Fatalf("video current = %q", videoTab.Current)
	}
	if len(videoTab.Items) != 1 {
		t.Fatalf("video item count = %d, want 1", len(videoTab.Items))
	}
}

func TestBuildCombinedPickerDataDefaultsInitialModeFromCurrentMode(t *testing.T) {
	manifest := strings.NewReader("static\t/x/a.png\nvideo\t/x/live.mp4\n")

	data, err := BuildCombinedPickerData(CombinedDataOptions{
		ManifestPath: "manifest.tsv",
		JSONPath:    "picker.json",
		CurrentMode: "static-random",
		CurrentPath: "/x/a.png",
	}, manifest)
	if err != nil {
		t.Fatalf("BuildCombinedPickerData failed: %v", err)
	}

	if data.InitialMode != "static" {
		t.Fatalf("initialMode = %q, want static", data.InitialMode)
	}
	if data.Tabs["static"].Current != "/x/a.png" {
		t.Fatalf("static current = %q", data.Tabs["static"].Current)
	}
	if data.Tabs["video"].Current != "" {
		t.Fatalf("video current = %q, want empty", data.Tabs["video"].Current)
	}
}

func TestGenerateCombinedPickerDataWritesJSON(t *testing.T) {
	tmp := t.TempDir()
	manifestPath := filepath.Join(tmp, "manifest.tsv")
	jsonPath := filepath.Join(tmp, "wallpaper-picker.json")
	manifest := "static\t" + filepath.Join(tmp, "one.png") + "\nvideo\t" + filepath.Join(tmp, "live.mp4") + "\n"
	if err := os.WriteFile(manifestPath, []byte(manifest), 0o600); err != nil {
		t.Fatalf("write manifest: %v", err)
	}

	err := GenerateCombinedPickerData(CombinedDataOptions{
		ManifestPath: manifestPath,
		JSONPath:    jsonPath,
		CurrentMode: "video",
		CurrentPath: filepath.Join(tmp, "live.mp4"),
		Script:      "orgm-hypr",
		ScriptArgs:  []string{"wallpaper"},
	})
	if err != nil {
		t.Fatalf("GenerateCombinedPickerData failed: %v", err)
	}

	content, err := os.ReadFile(jsonPath)
	if err != nil {
		t.Fatalf("read json: %v", err)
	}
	var data CombinedPickerData
	if err := json.Unmarshal(content, &data); err != nil {
		t.Fatalf("json unmarshal: %v\n%s", err, content)
	}
	if data.InitialMode != "video" {
		t.Fatalf("initialMode = %q, want video", data.InitialMode)
	}
	if data.Tabs["video"].Items[0].Thumb != filepath.Join(tmp, ".thumb", "live.mp4.jpg") {
		t.Fatalf("video thumb = %q", data.Tabs["video"].Items[0].Thumb)
	}
	if !strings.HasSuffix(string(content), "\n") {
		t.Fatalf("json output should end with newline")
	}
}
```

- [ ] **Step 2: Run the focused test and verify it fails**

Run:

```bash
go test ./internal/wallpaper -run 'TestBuildCombinedPickerData|TestGenerateCombinedPickerData' -count=1
```

Expected: FAIL with undefined identifiers like `BuildCombinedPickerData`, `CombinedDataOptions`, or `CombinedPickerData`.

- [ ] **Step 3: Add dual picker schema implementation**

In `internal/wallpaper/data.go`, after `type PickerData struct { ... }`, add:

```go
// PickerTab is one tab inside the combined Quickshell picker schema.
type PickerTab struct {
	Title         string       `json:"title"`
	ApplyCommand  string       `json:"applyCommand"`
	RandomCommand string       `json:"randomCommand"`
	Current       string       `json:"current"`
	Items         []PickerItem `json:"items"`
}

// CombinedPickerData is the JSON schema consumed by the unified Quickshell picker.
type CombinedPickerData struct {
	Mode        string               `json:"mode"`
	InitialMode string               `json:"initialMode"`
	Script      string               `json:"script"`
	ScriptArgs  []string             `json:"scriptArgs,omitempty"`
	Tabs        map[string]PickerTab `json:"tabs"`
}

// CombinedDataOptions configures combined Quickshell picker JSON generation.
type CombinedDataOptions struct {
	ManifestPath string
	JSONPath     string
	InitialMode  string
	CurrentMode  string
	CurrentPath  string
	Script       string
	ScriptArgs   []string
}
```

After `func (o DataOptions) validate() error { ... }`, add:

```go
func (o CombinedDataOptions) validate() error {
	if o.ManifestPath == "" {
		return fmt.Errorf("manifest path is required")
	}
	if o.JSONPath == "" {
		return fmt.Errorf("json path is required")
	}
	if o.InitialMode != "" {
		switch o.InitialMode {
		case "static", "video":
		default:
			return fmt.Errorf("initial mode must be static or video")
		}
	}
	return nil
}
```

After `GeneratePickerData`, add:

```go
// GenerateCombinedPickerData reads a TSV manifest and writes combined Quickshell picker JSON.
func GenerateCombinedPickerData(opts CombinedDataOptions) error {
	if err := opts.validate(); err != nil {
		return err
	}

	manifest, err := os.Open(opts.ManifestPath)
	if err != nil {
		return err
	}
	defer manifest.Close()

	data, err := BuildCombinedPickerData(opts, manifest)
	if err != nil {
		return err
	}

	output, err := os.Create(opts.JSONPath)
	if err != nil {
		return err
	}
	defer output.Close()

	encoder := json.NewEncoder(output)
	encoder.SetEscapeHTML(false)
	encoder.SetIndent("", "  ")
	if err := encoder.Encode(data); err != nil {
		return err
	}
	return output.Close()
}
```

After `BuildPickerData`, add:

```go
// BuildCombinedPickerData converts a manifest reader into the unified Quickshell schema.
func BuildCombinedPickerData(opts CombinedDataOptions, manifest io.Reader) (CombinedPickerData, error) {
	if err := opts.validate(); err != nil {
		return CombinedPickerData{}, err
	}

	initialMode := opts.InitialMode
	if initialMode == "" {
		initialMode = normalizedPickerMode(opts.CurrentMode)
	}
	if initialMode == "" {
		initialMode = "static"
	}

	data := CombinedPickerData{
		Mode:        "combined",
		InitialMode: initialMode,
		Script:      opts.Script,
		ScriptArgs:  opts.ScriptArgs,
		Tabs: map[string]PickerTab{
			"static": {
				Title:         titleForMode("static"),
				ApplyCommand:  applyCommandForMode("static"),
				RandomCommand: randomCommandForMode("static"),
				Items:         []PickerItem{},
			},
			"video": {
				Title:         titleForMode("video"),
				ApplyCommand:  applyCommandForMode("video"),
				RandomCommand: randomCommandForMode("video"),
				Items:         []PickerItem{},
			},
		},
	}
	if data.Script == "" {
		data.Script = "orgm-hypr"
	}

	currentMode := normalizedPickerMode(opts.CurrentMode)
	if currentMode != "" && opts.CurrentPath != "" {
		tab := data.Tabs[currentMode]
		tab.Current = opts.CurrentPath
		data.Tabs[currentMode] = tab
	}

	scanner := bufio.NewScanner(manifest)
	for scanner.Scan() {
		line := strings.TrimSuffix(scanner.Text(), "\n")
		if line == "" {
			continue
		}
		rowMode, wallpaperPath, ok := strings.Cut(line, "\t")
		if !ok {
			return CombinedPickerData{}, fmt.Errorf("invalid manifest row: %q", line)
		}
		mode := normalizedPickerMode(rowMode)
		tab, ok := data.Tabs[mode]
		if !ok {
			continue
		}
		tab.Items = append(tab.Items, PickerItem{
			Name:  filepath.Base(wallpaperPath),
			Path:  wallpaperPath,
			Thumb: paths.ThumbPath(wallpaperPath),
		})
		data.Tabs[mode] = tab
	}
	if err := scanner.Err(); err != nil {
		return CombinedPickerData{}, err
	}

	return data, nil
}
```

At the end of `data.go`, after `applyCommandForMode`, add:

```go
func randomCommandForMode(mode string) string {
	if mode == "video" {
		return "random-video"
	}
	return "random-static"
}

func normalizedPickerMode(mode string) string {
	switch mode {
	case "video":
		return "video"
	case "static", "static-random":
		return "static"
	default:
		return ""
	}
}
```

- [ ] **Step 4: Run focused tests and verify pass**

Run:

```bash
go test ./internal/wallpaper -run 'TestBuildPickerData|TestGeneratePickerData|TestBuildCombinedPickerData|TestGenerateCombinedPickerData' -count=1
```

Expected: PASS.

- [ ] **Step 5: Commit Task 1**

```bash
git add internal/wallpaper/data.go internal/wallpaper/data_test.go
git commit -m "feat: add combined wallpaper picker data"
```

---

### Task 2: Add CLI and manager support for direct picker + random by mode

**Files:**
- Modify: `internal/wallpaper/manager.go`
- Modify: `cmd/orgm-hypr/main.go`

- [ ] **Step 1: Write a failing manager-level test for combined data generation**

Create `internal/wallpaper/manager_test.go` if it does not exist, or append to it if it exists:

```go
package wallpaper

import (
	"encoding/json"
	"io"
	"os"
	"path/filepath"
	"testing"
)

func TestGenerateCombinedQuickshellDataUsesCurrentModeForInitialTab(t *testing.T) {
	tmp := t.TempDir()
	staticDir := filepath.Join(tmp, "Pictures", "Wallpapers")
	videoDir := filepath.Join(tmp, "Videos", "wallpapers")
	stateDir := filepath.Join(tmp, "state", "hypr-wallpaper")
	if err := os.MkdirAll(staticDir, 0o755); err != nil {
		t.Fatalf("mkdir static: %v", err)
	}
	if err := os.MkdirAll(videoDir, 0o755); err != nil {
		t.Fatalf("mkdir video: %v", err)
	}
	staticPath := filepath.Join(staticDir, "a.png")
	videoPath := filepath.Join(videoDir, "live.mp4")
	if err := os.WriteFile(staticPath, []byte("static"), 0o600); err != nil {
		t.Fatalf("write static: %v", err)
	}
	if err := os.WriteFile(videoPath, []byte("video"), 0o600); err != nil {
		t.Fatalf("write video: %v", err)
	}

	m := NewManager(io.Discard, io.Discard)
	m.StaticDir = staticDir
	m.VideoDir = videoDir
	m.StateDir = stateDir
	m.StateFile = filepath.Join(stateDir, "state")
	m.QuickshellManifest = filepath.Join(stateDir, "wallpaper-picker.tsv")
	if err := m.WriteState("video", videoPath); err != nil {
		t.Fatalf("WriteState: %v", err)
	}

	jsonPath := filepath.Join(stateDir, "wallpaper-picker-combined.json")
	if err := m.GenerateCombinedQuickshellData(jsonPath); err != nil {
		t.Fatalf("GenerateCombinedQuickshellData failed: %v", err)
	}

	content, err := os.ReadFile(jsonPath)
	if err != nil {
		t.Fatalf("read json: %v", err)
	}
	var data CombinedPickerData
	if err := json.Unmarshal(content, &data); err != nil {
		t.Fatalf("json unmarshal: %v\n%s", err, content)
	}
	if data.InitialMode != "video" {
		t.Fatalf("initialMode = %q, want video", data.InitialMode)
	}
	if len(data.Tabs["static"].Items) != 1 {
		t.Fatalf("static item count = %d, want 1", len(data.Tabs["static"].Items))
	}
	if len(data.Tabs["video"].Items) != 1 {
		t.Fatalf("video item count = %d, want 1", len(data.Tabs["video"].Items))
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
go test ./internal/wallpaper -run TestGenerateCombinedQuickshellDataUsesCurrentModeForInitialTab -count=1
```

Expected: FAIL because `GenerateCombinedQuickshellData` is undefined.

- [ ] **Step 3: Implement manager methods for combined data and direct picker**

In `internal/wallpaper/manager.go`, after `GenerateQuickshellData`, add:

```go
func (m *Manager) GenerateCombinedQuickshellData(jsonPath string) error {
	if err := m.ensureDirs(); err != nil {
		return err
	}
	manifestTmp := fmt.Sprintf("%s.%d", m.QuickshellManifest, os.Getpid())
	mf, err := os.Create(manifestTmp)
	if err != nil {
		return err
	}
	static, err := m.OrderedWallpapers("static")
	if err != nil {
		_ = mf.Close()
		return err
	}
	video, err := m.OrderedWallpapers("video")
	if err != nil {
		_ = mf.Close()
		return err
	}
	for _, path := range static {
		fmt.Fprintf(mf, "static\t%s\n", path)
	}
	for _, path := range video {
		fmt.Fprintf(mf, "video\t%s\n", path)
	}
	if err := mf.Close(); err != nil {
		return err
	}
	if err := os.Rename(manifestTmp, m.QuickshellManifest); err != nil {
		return err
	}
	_ = CleanStaleThumbnails(m.StaticDir)
	_ = CleanStaleThumbnails(m.VideoDir)

	currentMode := m.CurrentMode()
	currentPath := m.StateValue("path")
	tmpJSON := fmt.Sprintf("%s.%d", jsonPath, os.Getpid())
	if err := GenerateCombinedPickerData(CombinedDataOptions{
		ManifestPath: m.QuickshellManifest,
		JSONPath:     tmpJSON,
		CurrentMode:  currentMode,
		CurrentPath:  currentPath,
		Script:       "orgm-hypr",
		ScriptArgs:   []string{"wallpaper"},
	}); err != nil {
		return err
	}
	return os.Rename(tmpJSON, jsonPath)
}

func (m *Manager) OpenUnifiedQuickshellPicker() error {
	dataPath := filepath.Join(m.StateDir, "wallpaper-picker-combined.json")
	if err := m.GenerateCombinedQuickshellData(dataPath); err != nil {
		return err
	}
	input, err := os.ReadFile(dataPath)
	if err != nil {
		return err
	}
	if err := os.WriteFile(m.QuickshellData, input, 0o644); err != nil {
		return err
	}
	if err := m.WriteQuickshellRequest("combined", dataPath); err != nil {
		return err
	}
	return m.StartQuickshellPicker(true)
}
```

Replace the whole `MenuPick()` function in `internal/wallpaper/manager.go` with:

```go
func (m *Manager) MenuPick() error {
	return m.OpenUnifiedQuickshellPicker()
}
```

- [ ] **Step 4: Run manager test and verify pass**

```bash
go test ./internal/wallpaper -run TestGenerateCombinedQuickshellDataUsesCurrentModeForInitialTab -count=1
```

Expected: PASS.

- [ ] **Step 5: Add random subcommands to CLI**

In `cmd/orgm-hypr/main.go`, inside `runWallpaperWithIO`, insert this case between `set-video` and `pick`:

```go
	case "random-static":
		return m.SetRandomStatic()
	case "random-video":
		return m.SetRandomVideo()
	case "random":
		if len(args) < 2 {
			return cli.UsageError("usage: orgm-hypr wallpaper random [static|video]")
		}
		switch args[1] {
		case "static", "normal":
			return m.SetRandomStatic()
		case "video", "live":
			return m.SetRandomVideo()
		default:
			return cli.UsageError("usage: orgm-hypr wallpaper random [static|video]")
		}
```

Update the default usage string in the same switch to:

```go
		return cli.UsageError("usage: orgm-hypr wallpaper [restore|current|pick|random static|random video|carousel static|carousel video|set-static PATH|set-video PATH|status]")
```

- [ ] **Step 6: Run relevant Go tests**

```bash
go test ./internal/wallpaper ./cmd/orgm-hypr -count=1
```

Expected: PASS.

- [ ] **Step 7: Commit Task 2**

```bash
git add internal/wallpaper/manager.go internal/wallpaper/manager_test.go cmd/orgm-hypr/main.go
git commit -m "feat: open unified wallpaper picker"
```

---

### Task 3: Update Quickshell picker UI for tabs and Random

**Files:**
- Modify: `config/shared/.config/quickshell/wallpaper-picker/shell.qml`

- [ ] **Step 1: Back up the current QML in git diff only**

Run:

```bash
git diff -- config/shared/.config/quickshell/wallpaper-picker/shell.qml
```

Expected: no output before editing. If there is output, inspect it and preserve user changes before continuing.

- [ ] **Step 2: Replace mode/page properties with tab-aware properties**

In `shell.qml`, replace the existing data/page properties block:

```qml
  property var data: ({ title: "Wallpapers", mode: "static", applyCommand: "set-static", script: "orgm-hypr", scriptArgs: ["wallpaper"], current: "", items: [] })
  property int imageReloadNonce: 0
  property int pageSize: 16
  property int columns: 4
  property int currentPage: 0
  property int selectedInPage: 0
  property bool pendingShowPanel: false
  property int pageCount: Math.max(1, Math.ceil((data.items || []).length / pageSize))
  property var pageItems: (data.items || []).slice(currentPage * pageSize, currentPage * pageSize + pageSize)
```

with:

```qml
  property var data: ({ mode: "combined", initialMode: "static", script: "orgm-hypr", scriptArgs: ["wallpaper"], tabs: ({ static: { title: "Normal wallpapers", applyCommand: "set-static", randomCommand: "random-static", current: "", items: [] }, video: { title: "Live wallpapers", applyCommand: "set-video", randomCommand: "random-video", current: "", items: [] } }) })
  property string activeMode: "static"
  property int imageReloadNonce: 0
  property int pageSize: 16
  property int columns: 4
  property int currentPage: 0
  property int selectedInPage: 0
  property bool pendingShowPanel: false
  property var activeTab: root.tabForMode(root.activeMode)
  property var activeItems: activeTab.items || []
  property int pageCount: Math.max(1, Math.ceil(activeItems.length / pageSize))
  property var pageItems: activeItems.slice(currentPage * pageSize, currentPage * pageSize + pageSize)
```

- [ ] **Step 3: Add tab helper functions**

After `commandWithScriptArgs(args)`, add:

```qml
  function tabForMode(mode) {
    const tabs = root.data.tabs || ({})
    if (mode === "video" && tabs.video)
      return tabs.video
    if (tabs.static)
      return tabs.static
    return ({ title: mode === "video" ? "Live wallpapers" : "Normal wallpapers", applyCommand: mode === "video" ? "set-video" : "set-static", randomCommand: mode === "video" ? "random-video" : "random-static", current: "", items: [] })
  }

  function resetSelectionForActiveTab() {
    const current = root.activeTab.current || ""
    const index = Math.max(0, root.activeItems.findIndex(item => item.path === current))
    root.currentPage = Math.floor(index / root.pageSize)
    root.selectedInPage = index % root.pageSize
  }

  function setActiveMode(mode) {
    const nextMode = mode === "video" ? "video" : "static"
    if (nextMode === root.activeMode)
      return
    root.activeMode = nextMode
    root.resetSelectionForActiveTab()
    root.warmCurrentPage()
  }
```

- [ ] **Step 4: Update data loading for combined and legacy data**

Inside `loadData(showPanel)`, replace:

```qml
      root.data = JSON.parse(text)
      const currentIndex = Math.max(0, root.data.items.findIndex(item => item.path === root.data.current))
      root.currentPage = Math.floor(currentIndex / root.pageSize)
      root.selectedInPage = currentIndex % root.pageSize
```

with:

```qml
      const parsed = JSON.parse(text)
      if (!parsed.tabs) {
        const mode = parsed.mode === "video" ? "video" : "static"
        parsed.initialMode = mode
        parsed.tabs = ({})
        parsed.tabs[mode] = { title: parsed.title || (mode === "video" ? "Live wallpapers" : "Normal wallpapers"), applyCommand: parsed.applyCommand || (mode === "video" ? "set-video" : "set-static"), randomCommand: mode === "video" ? "random-video" : "random-static", current: parsed.current || "", items: parsed.items || [] }
        parsed.script = parsed.script || "orgm-hypr"
        parsed.scriptArgs = parsed.scriptArgs || ["wallpaper"]
      }
      root.data = parsed
      root.activeMode = parsed.initialMode === "video" ? "video" : "static"
      root.resetSelectionForActiveTab()
```

- [ ] **Step 5: Update warm page, selection, and apply functions**

Replace `warmCurrentPage()` with:

```qml
  function warmCurrentPage() {
    warmPageProc.command = root.commandWithScriptArgs(["warm-page", root.activeMode, String(root.currentPage), String(root.pageSize)])
    warmPageProc.running = true
  }
```

Replace `applySelected()` inside `overlay` with:

```qml
      function applySelected() {
        const item = root.selectedItem()
        if (!item || !item.path)
          return
        applyProc.command = root.commandWithScriptArgs([root.activeTab.applyCommand || (root.activeMode === "video" ? "set-video" : "set-static"), item.path])
        applyProc.startDetached()
        root.hidePanel()
      }

      function applyRandom() {
        applyProc.command = root.commandWithScriptArgs([root.activeTab.randomCommand || (root.activeMode === "video" ? "random-video" : "random-static")])
        applyProc.startDetached()
        root.hidePanel()
      }
```

Keep `selectedItem()` as-is because `root.pageItems` is now tab-aware.

- [ ] **Step 6: Update header UI with tabs**

In the header `Row`, replace the `Text { text: root.data.title || "Wallpapers" ... }` block with:

```qml
          Text {
            text: "Wallpapers"
            color: "#cad3f5"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 22
            font.bold: true
            width: 190
            elide: Text.ElideRight
          }

          Rectangle {
            width: 100
            height: 30
            radius: 8
            color: root.activeMode === "static" ? "#33494d64" : "#22363a4f"
            border.color: root.activeMode === "static" ? "#8aadf4" : "#494d64"
            Text { anchors.centerIn: parent; text: "NORMAL"; color: root.activeMode === "static" ? "#8aadf4" : "#cad3f5"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; font.bold: true }
            MouseArea { anchors.fill: parent; onClicked: root.setActiveMode("static") }
          }

          Rectangle {
            width: 100
            height: 30
            radius: 8
            color: root.activeMode === "video" ? "#33494d64" : "#22363a4f"
            border.color: root.activeMode === "video" ? "#8aadf4" : "#494d64"
            Text { anchors.centerIn: parent; text: "LIVE"; color: root.activeMode === "video" ? "#8aadf4" : "#cad3f5"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; font.bold: true }
            MouseArea { anchors.fill: parent; onClicked: root.setActiveMode("video") }
          }

          Item { width: parent.width - 190 - 100 - 100 - pager.width - helper.width - 88; height: 1 }
```

- [ ] **Step 7: Add empty-state text over the grid**

Inside `GridView { id: grid ... }`, before `delegate: Item {`, add:

```qml
          Text {
            anchors.centerIn: parent
            visible: root.activeItems.length === 0
            text: root.activeMode === "video" ? "No live wallpapers found" : "No normal wallpapers found"
            color: "#6e738d"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 18
          }
```

- [ ] **Step 8: Add Random footer button**

In the footer `Row`, after the `Next →` rectangle, add:

```qml
          Item { width: parent.width - 74 - 74 - 130 - 30; height: 1 }

          Rectangle {
            width: 130
            height: 26
            radius: 6
            color: "#22363a4f"
            border.color: "#a6da95"
            Text { anchors.centerIn: parent; text: "󰒟 Random"; color: "#a6da95"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; font.bold: true }
            MouseArea { anchors.fill: parent; onClicked: overlay.applyRandom() }
          }
```

- [ ] **Step 9: Run a syntax-oriented grep check**

Run:

```bash
rg -n "activeMode|applyRandom|NORMAL|LIVE|random-static|random-video" config/shared/.config/quickshell/wallpaper-picker/shell.qml
```

Expected: output includes all searched terms.

- [ ] **Step 10: Commit Task 3**

```bash
git add config/shared/.config/quickshell/wallpaper-picker/shell.qml
git commit -m "feat: add wallpaper picker tabs"
```

---

### Task 4: Update Waybar Hypr launcher

**Files:**
- Modify: `config/shared/.config/waybar-hypr/config`

- [ ] **Step 1: Edit Waybar wallpaper module**

In `config/shared/.config/waybar-hypr/config`, replace:

```json
    "custom/wallpaper": {
      "format": "󰸉",
      "tooltip": true,
      "tooltip-format": "Cambiar fondo aleatorio",
      "on-click": "orgm-hypr wallpaper next"
    },
```

with:

```json
    "custom/wallpaper": {
      "format": "󰸉",
      "tooltip": true,
      "tooltip-format": "Elegir wallpaper",
      "on-click": "orgm-hypr wallpaper pick"
    },
```

- [ ] **Step 2: Verify the exact Waybar command**

Run:

```bash
rg -n 'custom/wallpaper|Elegir wallpaper|orgm-hypr wallpaper pick|orgm-hypr wallpaper next' config/shared/.config/waybar-hypr/config
```

Expected: `orgm-hypr wallpaper pick` appears and `orgm-hypr wallpaper next` does not appear in the Hypr Waybar config.

- [ ] **Step 3: Commit Task 4**

```bash
git add config/shared/.config/waybar-hypr/config
git commit -m "fix: launch wallpaper menu from waybar"
```

---

### Task 5: Full verification and dotfiles sync check

**Files:**
- Verify: all modified files

- [ ] **Step 1: Run all Go tests**

```bash
go test ./...
```

Expected: PASS for all packages.

- [ ] **Step 2: Check repository status**

```bash
git status --short
```

Expected: only pre-existing local user changes remain, especially ` M steam.sh` if still present. No uncommitted implementation files.

- [ ] **Step 3: Check managed dotfile diff**

```bash
orgm-dot diff --host orgm
```

Expected: diff shows Quickshell/Waybar wallpaper menu changes that match this plan. Do not sync if unrelated destructive changes appear.

- [ ] **Step 4: Sync dotfiles to host**

```bash
orgm-dot sync --host orgm
```

Expected: config is applied to `/home/osmarg/.config/...` for host `orgm`.

- [ ] **Step 5: Restart Waybar or ask existing watcher to reload**

If `orgm-hypr waybar watch` is not running, run:

```bash
pkill -x waybar || true
orgm-hypr waybar start >/tmp/orgm-hypr-waybar-restart.log 2>&1 &
```

Expected: Waybar restarts without blocking the terminal.

- [ ] **Step 6: Manual desktop verification**

Run or click:

```bash
orgm-hypr wallpaper pick
```

Expected:

- Quickshell menu opens directly.
- No fuzzel/rofi menu appears.
- If current state is `mode=video`, LIVE tab opens; otherwise NORMAL opens.
- NORMAL tab item click applies a static wallpaper.
- LIVE tab item click applies a live wallpaper.
- Random in NORMAL applies a static random wallpaper.
- Random in LIVE applies a live random wallpaper.

- [ ] **Step 7: Final commit if verification changed tracked files**

If verification required any additional tracked fixes:

```bash
git add <fixed-files>
git commit -m "fix: verify wallpaper picker integration"
```

If no tracked files changed, skip this commit.
