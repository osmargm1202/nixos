# ORGM Helper Script Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove runtime dependence on `orgm-hypr`, restore shell-script glue, keep only `orgm-dot`, `orgm-calendar`, and `orgm-wallpaper` as Go helpers, and add static wallpaper selection per monitor.

**Architecture:** Dotfiles call shell scripts for Hyprland glue and direct Go binaries only for dot/calendar/wallpaper. `orgm-wallpaper` gains monitor-aware static state while preserving global fallback behavior. NixOS stops installing/exporting `orgm-hypr` and keeps the three focused Go packages.

**Tech Stack:** POSIX/Bash scripts, Hyprland Lua config, Waybar JSONC, Quickshell QML, Go 1.23 tests, Nix flakes.

---

### Task 1: Fix calendar command order

**Files:**
- Modify: `internal/calendar/calendar.go`
- Test: `internal/calendar/calendar_test.go`

- [ ] **Step 1: Write failing test for gcalcli command order**

Add this test to `internal/calendar/calendar_test.go`:

```go
func TestGcalcliCommandPutsTSVAfterAgenda(t *testing.T) {
	t.Setenv("ORGM_CALENDAR_GCALCLI_CMD", "")
	cmd, ok := gcalcliCommand()
	if !ok {
		t.Skip("gcalcli not installed in test PATH")
	}
	joined := strings.Join(cmd, " ")
	if !strings.Contains(joined, "agenda --tsv") {
		t.Fatalf("gcalcli command = %q, want agenda before --tsv", joined)
	}
}
```

Ensure `strings` is imported if missing.

- [ ] **Step 2: Run RED**

Run:

```bash
go test ./internal/calendar -run TestGcalcliCommandPutsTSVAfterAgenda -count=1
```

Expected: FAIL because current command contains `--tsv agenda`.

- [ ] **Step 3: Implement command order fix**

Change `gcalcliCommand()` in `internal/calendar/calendar.go` to return:

```go
return []string{p, "--nocolor", "agenda", "--tsv", "--details", "calendar", "--details", "url"}, true
```

- [ ] **Step 4: Run GREEN**

Run:

```bash
go test ./internal/calendar -run TestGcalcliCommandPutsTSVAfterAgenda -count=1
```

Expected: PASS.

---

### Task 2: Add monitor-aware static wallpaper state

**Files:**
- Modify: `internal/wallpaper/manager.go`
- Test: `internal/wallpaper/manager_test.go`

- [ ] **Step 1: Write failing tests**

Add tests that assert monitor state path sanitization, per-monitor state writing, and restore config generation:

```go
func TestWriteMonitorStateUsesSanitizedOutputName(t *testing.T) {
	tmp := t.TempDir()
	m := NewManager(io.Discard, io.Discard)
	m.StateDir = filepath.Join(tmp, "state")
	wallpaper := filepath.Join(tmp, "wall.png")
	if err := os.WriteFile(wallpaper, []byte("x"), 0o600); err != nil {
		t.Fatalf("write wallpaper: %v", err)
	}
	if err := m.WriteMonitorState("HDMI-A-1", "static", wallpaper); err != nil {
		t.Fatalf("WriteMonitorState: %v", err)
	}
	got := readTrim(filepath.Join(m.StateDir, "monitors", "HDMI-A-1.state"))
	want := "mode=static\npath=" + wallpaper
	if got != want {
		t.Fatalf("state = %q, want %q", got, want)
	}
}

func TestWriteHyprpaperConfigIncludesMonitorSpecificWallpapers(t *testing.T) {
	tmp := t.TempDir()
	m := NewManager(io.Discard, io.Discard)
	m.HyprpaperConf = filepath.Join(tmp, "hyprpaper.conf")
	wallA := filepath.Join(tmp, "a.png")
	wallB := filepath.Join(tmp, "b.png")
	for _, path := range []string{wallA, wallB} {
		if err := os.WriteFile(path, []byte("x"), 0o600); err != nil {
			t.Fatalf("write %s: %v", path, err)
		}
	}
	states := []MonitorState{{Output: "DP-3", Mode: "static", Path: wallA}, {Output: "HDMI-A-1", Mode: "static", Path: wallB}}
	if err := m.writeHyprpaperMonitorConfig(states); err != nil {
		t.Fatalf("writeHyprpaperMonitorConfig: %v", err)
	}
	content := readTrim(m.HyprpaperConf)
	for _, want := range []string{"monitor = DP-3", "path = " + wallA, "monitor = HDMI-A-1", "path = " + wallB} {
		if !strings.Contains(content, want) {
			t.Fatalf("hyprpaper.conf missing %q:\n%s", want, content)
		}
	}
}
```

Ensure `strings` is imported.

- [ ] **Step 2: Run RED**

Run:

```bash
go test ./internal/wallpaper -run 'TestWriteMonitorStateUsesSanitizedOutputName|TestWriteHyprpaperConfigIncludesMonitorSpecificWallpapers' -count=1
```

Expected: FAIL because `WriteMonitorState`, `MonitorState`, and `writeHyprpaperMonitorConfig` do not exist.

- [ ] **Step 3: Implement monitor helpers**

Add `MonitorState`, `monitorStatePath`, `sanitizeOutputName`, `WriteMonitorState`, `ReadMonitorStates`, and `writeHyprpaperMonitorConfig` to `internal/wallpaper/manager.go`. State files live under `m.StateDir/monitors/<sanitized>.state` and contain `mode=` and `path=` lines.

- [ ] **Step 4: Run GREEN**

Run:

```bash
go test ./internal/wallpaper -run 'TestWriteMonitorStateUsesSanitizedOutputName|TestWriteHyprpaperConfigIncludesMonitorSpecificWallpapers' -count=1
```

Expected: PASS.

---

### Task 3: Add monitor-aware `orgm-wallpaper` commands

**Files:**
- Modify: `cmd/orgm-wallpaper/main.go`
- Modify: `internal/wallpaper/manager.go`
- Test: `cmd/orgm-wallpaper/main_test.go`

- [ ] **Step 1: Write failing CLI tests**

Create `cmd/orgm-wallpaper/main_test.go` with tests for parsing `--monitor` on `set-static`, `random static`, and `status --monitor`. Use temp files and test-friendly manager paths where needed.

- [ ] **Step 2: Run RED**

Run:

```bash
go test ./cmd/orgm-wallpaper -count=1
```

Expected: FAIL because commands are not implemented.

- [ ] **Step 3: Implement CLI commands**

Update `cmd/orgm-wallpaper/main.go` to support:

```text
orgm-wallpaper set-static PATH [--monitor OUTPUT]
orgm-wallpaper random static [--monitor OUTPUT]
orgm-wallpaper random-static [--monitor OUTPUT]
orgm-wallpaper status [--monitor OUTPUT]
```

Without `--monitor`, keep existing behavior.

- [ ] **Step 4: Implement manager methods**

Add:

```go
func (m *Manager) SetStaticForMonitor(path, output, mode string) error
func (m *Manager) SetRandomStaticForMonitor(output string) error
func (m *Manager) StatusForMonitor(output string) error
```

`SetStaticForMonitor` writes monitor state, writes hyprpaper config for all monitor states, restarts hyprpaper, updates compatibility current file/symlink, and does not alter video state.

- [ ] **Step 5: Run GREEN**

Run:

```bash
go test ./cmd/orgm-wallpaper ./internal/wallpaper -count=1
```

Expected: PASS.

---

### Task 4: Rewire dotfiles away from `orgm-hypr`

**Files:**
- Modify: `config/shared/.config/hypr/lua/autostart.lua`
- Modify: `config/shared/.config/hypr/lua/keybindings.lua`
- Modify: `config/shared/.config/hypr/lua/programs.lua`
- Modify: `config/shared/.config/waybar-hypr/config`
- Modify: `config/shared/.config/quickshell/calendar/shell.qml`
- Modify: `config/shared/.config/quickshell/wallpaper-picker/shell.qml`
- Create: `config/shared/.local/bin/hypr-keyhelper`
- Create: `config/shared/.local/bin/hypr-session-import-env`
- Create: `config/shared/.local/bin/hypr-start-containers`
- Create: `config/shared/.local/bin/hypr-start-discord`
- Create: `config/shared/.local/bin/hypr-pi-prompt`
- Create: `config/shared/.local/bin/hypr-obsidian-open-or-focus`

- [ ] **Step 1: Add helper scripts**

Create focused executable scripts for key helper, session import, containers, Discord, Pi prompt, and Obsidian focus/open. Scripts must not call `orgm-hypr`.

- [ ] **Step 2: Rewire configs**

Replace calls:

```text
orgm-hypr calendar ... -> orgm-calendar ...
orgm-hypr wallpaper ... -> orgm-wallpaper ...
orgm-hypr helper ... -> hypr-keyhelper ...
orgm-hypr session import-env -> hypr-session-import-env
orgm-hypr session start-containers arch windows -> hypr-start-containers arch windows
orgm-hypr session start-discord -> hypr-start-discord
orgm-hypr pi prompt --launcher fuzzel -> hypr-pi-prompt --launcher fuzzel
orgm-hypr obsidian open-or-focus -> hypr-obsidian-open-or-focus
```

- [ ] **Step 3: Add Waybar main monitor output**

Add `"output": "DP-3"` to `top_bar` and `bottom_bar` in `config/shared/.config/waybar-hypr/config`.

- [ ] **Step 4: Verify no runtime references**

Run:

```bash
rg -n "orgm-hypr" config/shared/.config config/shared/.local/bin
```

Expected: no matches except docs/README if not runtime-loaded.

---

### Task 5: Update Quickshell wallpaper monitor target

**Files:**
- Modify: `internal/wallpaper/data.go`
- Modify: `internal/wallpaper/data_test.go`
- Modify: `config/shared/.config/quickshell/wallpaper-picker/shell.qml`

- [ ] **Step 1: Add data-schema test**

Add test asserting `CombinedPickerData` includes monitor outputs when provided.

- [ ] **Step 2: Run RED**

Run:

```bash
go test ./internal/wallpaper -run TestBuildCombinedPickerDataIncludesMonitors -count=1
```

Expected: FAIL.

- [ ] **Step 3: Add monitor fields**

Add monitor list to combined picker JSON. Generate monitor list from `hyprctl -j monitors` when possible, with fallback empty list.

- [ ] **Step 4: Update QML command building**

In `shell.qml`, add selected monitor state and append `--monitor OUTPUT` for static apply/random commands only.

- [ ] **Step 5: Run GREEN**

Run:

```bash
go test ./internal/wallpaper -count=1
```

Expected: PASS.

---

### Task 6: Remove `orgm-hypr` from NixOS packaging

**Files:**
- Modify: `/home/osmarg/Hobby/nixos/flake.nix`
- Modify: `/home/osmarg/Hobby/nixos/nixos/profiles/hyprland.nix`

- [ ] **Step 1: Remove package/profile references**

Remove `orgmHypr` binding, package output, and installed package entry. Keep `orgmDot`, `orgmWallpaper`, and `orgmCalendar`.

- [ ] **Step 2: Verify Nix references**

Run:

```bash
cd /home/osmarg/Hobby/nixos
rg -n "orgmHypr|orgm-hypr" flake.nix nixos/profiles/hyprland.nix nixos/packages
```

Expected: no live references except possibly the unused `nixos/packages/orgm-hypr.nix` file if not deleted.

---

### Task 7: Full verification and sync preview

**Files:**
- Verify only.

- [ ] **Step 1: Run Go tests in dotfiles**

```bash
go test ./cmd/orgm-wallpaper ./cmd/orgm-calendar ./internal/calendar ./internal/wallpaper ./cmd/orgm-dot ./internal/dot...
```

Expected: PASS.

- [ ] **Step 2: Run Go tests in NixOS if touched**

```bash
cd /home/osmarg/Hobby/nixos
go test ./...
```

Expected: PASS or report unrelated pre-existing failures.

- [ ] **Step 3: Preview dotfiles sync**

```bash
distrobox-host-exec orgm-dot diff
```

Expected: shows planned rewired config/script changes.

- [ ] **Step 4: Report runtime next steps**

Do not destructively rebuild or restart user session without explicit instruction. Report exact commands to run for sync/rebuild/restart.
