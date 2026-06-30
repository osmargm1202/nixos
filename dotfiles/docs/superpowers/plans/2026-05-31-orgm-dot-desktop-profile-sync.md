# orgm-dot Desktop Profile Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `orgm-dot` filter managed paths by active graphical desktop so GNOME is left alone and Hyprland/labwc/Sway only receive matching helpers/config.

**Architecture:** Add a pure desktop-profile filter in `internal/dotsync`, driven by `ORGM_DOT_DESKTOP` override or session env detection. `Run` resolves the profile once, filters shared and host path lists before `syncOne`, and keeps unknown profiles on current behavior.

**Tech Stack:** Go standard library, existing `internal/dotsync`, `internal/dotconfig`, `internal/dotmanifest`, Go unit tests.

---

## File Structure

- Modify `internal/dotsync/sync.go` — add `DesktopProfile`, environment detection, path filtering helpers, and call filter from `Run`.
- Modify `internal/dotsync/sync_test.go` — add unit tests for profile detection and sync filtering.
- No changes to `config/dotfiles.json` in this slice.
- No `orgm-dot sync` during implementation.

---

### Task 1: Add desktop profile tests

**Files:**
- Modify: `internal/dotsync/sync_test.go`

- [ ] **Step 1: Add failing tests for path filtering and override detection**

Append this code to `internal/dotsync/sync_test.go`:

```go
func TestDesktopProfileFromEnvUsesOverride(t *testing.T) {
	lookup := mapLookup(map[string]string{"ORGM_DOT_DESKTOP": "sway"})

	profile, err := desktopProfileFromEnv(lookup)
	if err != nil {
		t.Fatal(err)
	}

	if profile != DesktopSway {
		t.Fatalf("profile = %q, want %q", profile, DesktopSway)
	}
}

func TestDesktopProfileFromEnvRejectsInvalidOverride(t *testing.T) {
	lookup := mapLookup(map[string]string{"ORGM_DOT_DESKTOP": "plasma"})

	_, err := desktopProfileFromEnv(lookup)
	if err == nil {
		t.Fatal("expected invalid ORGM_DOT_DESKTOP error")
	}
}

func TestDesktopProfileFromEnvDetectsHyprland(t *testing.T) {
	lookup := mapLookup(map[string]string{"XDG_CURRENT_DESKTOP": "Hyprland"})

	profile, err := desktopProfileFromEnv(lookup)
	if err != nil {
		t.Fatal(err)
	}

	if profile != DesktopHyprland {
		t.Fatalf("profile = %q, want %q", profile, DesktopHyprland)
	}
}

func TestShouldSyncPathForGNOMEBlocksCompositorPaths(t *testing.T) {
	blocked := []string{
		".config/hypr",
		".config/hypr/lua/autostart.lua",
		".config/labwc",
		".config/sway",
		".config/waybar-hypr/config.jsonc",
		".config/nwg-dock-hyprland/style.css",
		".local/bin/hypr-main-menu",
		".local/bin/sway-app-dock",
		".local/bin/labwc-kill-windows",
		".local/bin/waybar-watch",
		".local/bin/volume-osd",
	}
	for _, rel := range blocked {
		if shouldSyncPath(DesktopGNOME, rel) {
			t.Fatalf("GNOME should block %s", rel)
		}
	}

	allowed := []string{
		".config/fish",
		".config/kitty",
		".local/bin/windows-rdp",
		".pi/agent/AGENTS.md",
	}
	for _, rel := range allowed {
		if !shouldSyncPath(DesktopGNOME, rel) {
			t.Fatalf("GNOME should allow %s", rel)
		}
	}
}

func TestShouldSyncPathForLabwcAllowsLabwcAndBlocksHyprland(t *testing.T) {
	allowed := []string{".config/labwc", ".config/labwc/rc.xml", ".local/bin/labwc-kill-windows"}
	for _, rel := range allowed {
		if !shouldSyncPath(DesktopLabwc, rel) {
			t.Fatalf("labwc should allow %s", rel)
		}
	}

	blocked := []string{".config/hypr", ".config/orgm-hypr", ".config/waybar-hypr", ".local/bin/hypr-main-menu"}
	for _, rel := range blocked {
		if shouldSyncPath(DesktopLabwc, rel) {
			t.Fatalf("labwc should block %s", rel)
		}
	}
}

func TestShouldSyncPathForSwayAllowsSwayAndLabwcButBlocksHyprland(t *testing.T) {
	allowed := []string{".config/sway", ".config/sway/config", ".local/bin/sway-app-dock", ".local/bin/labwc-kill-windows"}
	for _, rel := range allowed {
		if !shouldSyncPath(DesktopSway, rel) {
			t.Fatalf("sway should allow %s", rel)
		}
	}

	blocked := []string{".config/hypr", ".config/orgm-hypr", ".config/waybar-hypr", ".local/bin/hypr-main-menu"}
	for _, rel := range blocked {
		if shouldSyncPath(DesktopSway, rel) {
			t.Fatalf("sway should block %s", rel)
		}
	}
}

func TestShouldSyncPathForUnknownKeepsCurrentBehavior(t *testing.T) {
	paths := []string{".config/hypr", ".config/labwc", ".config/sway", ".local/bin/hypr-main-menu"}
	for _, rel := range paths {
		if !shouldSyncPath(DesktopAll, rel) {
			t.Fatalf("all should allow %s", rel)
		}
	}
}

func TestRunFiltersSharedPathsByDesktopProfile(t *testing.T) {
	t.Setenv("ORGM_DOT_DESKTOP", "gnome")
	rt := testRuntime(t)
	rt.Config.Shared.Paths = []string{".config/fish", ".config/hypr", ".local/bin/hypr-main-menu"}
	writeFile(t, filepath.Join(rt.SourceShared, ".config", "fish", "config.fish"), "fish")
	writeFile(t, filepath.Join(rt.SourceShared, ".config", "hypr", "hyprland.conf"), "hypr")
	writeFile(t, filepath.Join(rt.SourceShared, ".local", "bin", "hypr-main-menu"), "hypr")

	actions, err := Run(rt, Options{})
	if err != nil {
		t.Fatal(err)
	}

	assertHasAction(t, actions, "A", filepath.Join(rt.Destination, ".config", "fish", "config.fish"))
	assertNoAction(t, actions, filepath.Join(rt.Destination, ".config", "hypr", "hyprland.conf"))
	assertNoAction(t, actions, filepath.Join(rt.Destination, ".local", "bin", "hypr-main-menu"))
}

func mapLookup(values map[string]string) func(string) string {
	return func(key string) string {
		return values[key]
	}
}
```

- [ ] **Step 2: Run tests to verify red**

Run:

```bash
go test ./internal/dotsync
```

Expected: FAIL with errors like `undefined: desktopProfileFromEnv`, `undefined: DesktopSway`, and `undefined: shouldSyncPath`.

- [ ] **Step 3: Commit red tests**

```bash
git add internal/dotsync/sync_test.go
git commit -m "test: cover desktop-aware dot sync filtering"
```

---

### Task 2: Implement desktop profile detection and path filter

**Files:**
- Modify: `internal/dotsync/sync.go`

- [ ] **Step 1: Add imports needed by detection**

In `internal/dotsync/sync.go`, change the import block to include `strings`:

```go
import (
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"syscall"

	"github.com/osmargm1202/nixos/internal/dotconfig"
	"github.com/osmargm1202/nixos/internal/dotmanifest"
)
```

- [ ] **Step 2: Add profile constants and detection helpers**

Insert this code after `type Action struct` in `internal/dotsync/sync.go`:

```go
type DesktopProfile string

const (
	DesktopAll      DesktopProfile = "all"
	DesktopHyprland DesktopProfile = "hyprland"
	DesktopGNOME    DesktopProfile = "gnome"
	DesktopLabwc    DesktopProfile = "labwc"
	DesktopSway     DesktopProfile = "sway"
)

type envLookup func(string) string

func desktopProfileFromEnv(lookup envLookup) (DesktopProfile, error) {
	if override := strings.TrimSpace(strings.ToLower(lookup("ORGM_DOT_DESKTOP"))); override != "" {
		switch override {
		case string(DesktopAll):
			return DesktopAll, nil
		case string(DesktopHyprland):
			return DesktopHyprland, nil
		case string(DesktopGNOME):
			return DesktopGNOME, nil
		case string(DesktopLabwc):
			return DesktopLabwc, nil
		case string(DesktopSway):
			return DesktopSway, nil
		default:
			return "", fmt.Errorf("invalid ORGM_DOT_DESKTOP %q: expected hyprland, gnome, labwc, sway, or all", override)
		}
	}

	if strings.TrimSpace(lookup("HYPRLAND_INSTANCE_SIGNATURE")) != "" {
		return DesktopHyprland, nil
	}

	joined := strings.ToLower(strings.Join([]string{
		lookup("XDG_CURRENT_DESKTOP"),
		lookup("DESKTOP_SESSION"),
		lookup("XDG_SESSION_DESKTOP"),
	}, ":"))

	switch {
	case strings.Contains(joined, "hyprland"):
		return DesktopHyprland, nil
	case strings.Contains(joined, "gnome"):
		return DesktopGNOME, nil
	case strings.Contains(joined, "labwc"):
		return DesktopLabwc, nil
	case strings.Contains(joined, "sway"):
		return DesktopSway, nil
	default:
		return DesktopAll, nil
	}
}

func currentDesktopProfile() (DesktopProfile, error) {
	return desktopProfileFromEnv(os.Getenv)
}
```

- [ ] **Step 3: Add path filter helpers**

Insert this code below `currentDesktopProfile`:

```go
func shouldSyncPath(profile DesktopProfile, rel string) bool {
	rel = dotmanifest.Normalize(rel)
	switch profile {
	case DesktopGNOME:
		return !isAnyDesktopSpecificPath(rel)
	case DesktopLabwc:
		return !isHyprlandPath(rel) && !isSwayPath(rel)
	case DesktopSway:
		return !isHyprlandPath(rel)
	case DesktopHyprland, DesktopAll, "":
		return true
	default:
		return true
	}
}

func isAnyDesktopSpecificPath(rel string) bool {
	return isHyprlandPath(rel) || isLabwcPath(rel) || isSwayPath(rel) || hasPathPrefix(rel, ".config/waybar") || isDesktopHelper(rel)
}

func isHyprlandPath(rel string) bool {
	return hasPathPrefix(rel, ".config/hypr") ||
		hasPathPrefix(rel, ".config/orgm-hypr") ||
		hasPathPrefix(rel, ".config/waybar-hypr") ||
		hasPathPrefix(rel, ".config/nwg-dock-hyprland") ||
		hasBasePrefix(rel, "hypr-") ||
		rel == ".local/bin/fuzzel-hypr-window" ||
		rel == ".local/bin/brightness-osd" ||
		rel == ".local/bin/mic-volume-osd" ||
		rel == ".local/bin/volume-osd" ||
		rel == ".local/bin/waybar-date-es" ||
		rel == ".local/bin/waybar-day-month-es" ||
		rel == ".local/bin/waybar-swap-usage" ||
		rel == ".local/bin/waybar-time-ampm" ||
		rel == ".local/bin/waybar-watch"
}

func isLabwcPath(rel string) bool {
	return hasPathPrefix(rel, ".config/labwc") || hasBasePrefix(rel, "labwc-")
}

func isSwayPath(rel string) bool {
	return hasPathPrefix(rel, ".config/sway") ||
		hasPathPrefix(rel, ".config/swaylock") ||
		hasPathPrefix(rel, ".config/swaync") ||
		hasBasePrefix(rel, "sway-")
}

func isDesktopHelper(rel string) bool {
	return hasBasePrefix(rel, "hypr-") || hasBasePrefix(rel, "labwc-") || hasBasePrefix(rel, "sway-") ||
		rel == ".local/bin/fuzzel-hypr-window" ||
		strings.HasPrefix(filepath.Base(rel), "waybar-") ||
		strings.HasSuffix(filepath.Base(rel), "-osd")
}

func hasPathPrefix(rel, prefix string) bool {
	return rel == prefix || strings.HasPrefix(rel, prefix+"/")
}

func hasBasePrefix(rel, prefix string) bool {
	return strings.HasPrefix(filepath.Base(rel), prefix)
}
```

- [ ] **Step 4: Run focused tests**

Run:

```bash
go test ./internal/dotsync
```

Expected: still FAIL on `TestRunFiltersSharedPathsByDesktopProfile` because `Run` does not call the filter yet.

- [ ] **Step 5: Wire filter into Run**

In `internal/dotsync/sync.go`, replace the start of `Run` after lock setup with profile resolution and checks. The final `Run` body should include this block before loops:

```go
	profile, err := currentDesktopProfile()
	if err != nil {
		return nil, err
	}

	var actions []Action
	for _, rel := range rt.Config.Shared.Paths {
		if !shouldSyncPath(profile, rel) {
			continue
		}
		as, err := syncOne(rt, rt.SourceShared, rel, opts)
		if err != nil {
			return nil, err
		}
		actions = append(actions, as...)
	}
	for _, rel := range rt.HostPaths(opts.Host) {
		if !shouldSyncPath(profile, rel) {
			continue
		}
		as, err := syncOne(rt, rt.HostSource(opts.Host), rel, opts)
		if err != nil {
			return nil, err
		}
		actions = append(actions, as...)
	}
	return actions, nil
```

- [ ] **Step 6: Run focused tests to verify green**

Run:

```bash
go test ./internal/dotsync
```

Expected: PASS.

- [ ] **Step 7: Commit implementation**

```bash
git add internal/dotsync/sync.go internal/dotsync/sync_test.go
git commit -m "feat: filter orgm-dot sync by desktop profile"
```

---

### Task 3: Add integration-style coverage for host paths and invalid override

**Files:**
- Modify: `internal/dotsync/sync_test.go`

- [ ] **Step 1: Add tests for host paths and invalid override in Run**

Append this code to `internal/dotsync/sync_test.go`:

```go
func TestRunFiltersHostPathsByDesktopProfile(t *testing.T) {
	t.Setenv("ORGM_DOT_DESKTOP", "gnome")
	rt := testRuntime(t)
	rt.Config.Shared.Paths = nil
	rt.Config.Hosts = map[string]dotconfig.PathList{
		"orgm": {Paths: []string{".config/fish/host-orgm.fish", ".config/rofi/hypr-menu.env"}},
	}
	writeFile(t, filepath.Join(rt.HostSource("orgm"), ".config", "fish", "host-orgm.fish"), "fish")
	writeFile(t, filepath.Join(rt.HostSource("orgm"), ".config", "rofi", "hypr-menu.env"), "hypr")

	actions, err := Run(rt, Options{Host: "orgm"})
	if err != nil {
		t.Fatal(err)
	}

	assertHasAction(t, actions, "A", filepath.Join(rt.Destination, ".config", "fish", "host-orgm.fish"))
	assertNoAction(t, actions, filepath.Join(rt.Destination, ".config", "rofi", "hypr-menu.env"))
}

func TestRunReturnsInvalidDesktopOverrideError(t *testing.T) {
	t.Setenv("ORGM_DOT_DESKTOP", "plasma")
	rt := testRuntime(t)

	_, err := Run(rt, Options{})
	if err == nil {
		t.Fatal("expected invalid desktop override error")
	}
}
```

- [ ] **Step 2: Run tests**

Run:

```bash
go test ./internal/dotsync
```

Expected: PASS.

- [ ] **Step 3: If host-path test fails for `.config/rofi/hypr-menu.env`, update filter**

If `TestRunFiltersHostPathsByDesktopProfile` fails because `.config/rofi/hypr-menu.env` syncs in GNOME, add this condition to `isHyprlandPath`:

```go
		rel == ".config/rofi/hypr-menu.env" ||
```

Then rerun:

```bash
go test ./internal/dotsync
```

Expected: PASS.

- [ ] **Step 4: Commit additional coverage**

```bash
git add internal/dotsync/sync.go internal/dotsync/sync_test.go
git commit -m "test: cover desktop filtering for host paths"
```

---

### Task 4: Full verification and inspect orgm-dot diff safely

**Files:**
- No required source changes unless tests reveal issues.

- [ ] **Step 1: Run focused package tests**

```bash
go test ./internal/dotsync ./internal/dotconfig
```

Expected: PASS.

- [ ] **Step 2: Run full test suite**

```bash
go test ./...
```

Expected: PASS.

- [ ] **Step 3: Run whitespace diff check**

```bash
git diff --check
```

Expected: no output.

- [ ] **Step 4: Inspect dry-run/diff behavior without syncing**

```bash
ORGM_DOT_DESKTOP=gnome go run ./cmd/orgm-dot diff
```

Expected: no Hyprland/labwc/Sway helper changes should appear because GNOME blocks compositor-specific paths. If `diff` command path does not use `dotsync.Run`, record the limitation and do not change unrelated diff behavior in this slice.

- [ ] **Step 5: Final commit if verification-only notes required**

If no files changed, skip commit. If a small code/test fix was needed:

```bash
git add internal/dotsync/sync.go internal/dotsync/sync_test.go
git commit -m "fix: align desktop profile sync filtering"
```

---

## Self-Review

Spec coverage:

- Desktop profiles and override covered in Tasks 1-2.
- GNOME blocks compositor-specific paths covered in Tasks 1-3.
- labwc allows labwc and blocks Hyprland covered in Task 1.
- Sway allows Sway + labwc and blocks Hyprland covered in Task 1.
- Unknown/all preserves current behavior covered in Task 1.
- No deletion behavior: implementation only skips `syncOne`; no delete cleanup added.
- Verification commands covered in Task 4.

Placeholder scan: no TBD/TODO placeholders. Conditional step in Task 3 has exact code and command.

Type consistency: plan uses `DesktopProfile`, `DesktopAll`, `DesktopHyprland`, `DesktopGNOME`, `DesktopLabwc`, `DesktopSway`, `desktopProfileFromEnv`, `currentDesktopProfile`, `shouldSyncPath`; all defined in Task 2 before final verification.
