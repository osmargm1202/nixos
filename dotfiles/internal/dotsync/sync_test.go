package dotsync

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/osmargm1202/nixos/internal/dotconfig"
	"github.com/osmargm1202/nixos/internal/dotmanifest"
)

func TestRunReplacesDestinationSymlinkWhenSourceIsManagedFile(t *testing.T) {
	rt := testRuntime(t)
	managedFile := filepath.Join(rt.SourceShared, ".config", "app", "config.json")
	writeFile(t, managedFile, "repo")
	dstLink := filepath.Join(rt.Destination, ".config", "app", "config.json")
	if err := os.MkdirAll(filepath.Dir(dstLink), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink("/nix/store/generated", dstLink); err != nil {
		t.Fatal(err)
	}

	actions, err := Run(rt, Options{})
	if err != nil {
		t.Fatal(err)
	}

	assertHasAction(t, actions, "M", dstLink)
	if info, err := os.Lstat(dstLink); err != nil {
		t.Fatal(err)
	} else if info.Mode()&os.ModeSymlink != 0 {
		t.Fatal("managed file should replace destination symlink")
	}
}

func TestRunCopiesManagedSourceSymlinksEvenWhenDestinationSymlinksAreLocalOnly(t *testing.T) {
	rt := testRuntime(t)
	srcLink := filepath.Join(rt.SourceShared, ".config", "app", "managed-link")
	if err := os.MkdirAll(filepath.Dir(srcLink), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink("managed-target", srcLink); err != nil {
		t.Fatal(err)
	}

	actions, err := Run(rt, Options{})
	if err != nil {
		t.Fatal(err)
	}

	dstLink := filepath.Join(rt.Destination, ".config", "app", "managed-link")
	assertHasAction(t, actions, "A", dstLink)
	target, err := os.Readlink(dstLink)
	if err != nil {
		t.Fatalf("managed source symlink should be copied: %v", err)
	}
	if target != "managed-target" {
		t.Fatalf("symlink target = %q, want managed-target", target)
	}
}

func TestRunPreservesConfiguredLocalOnlyTypesAndPatterns(t *testing.T) {
	rt := testRuntime(t)
	writeFile(t, filepath.Join(rt.SourceShared, ".config", "app", "config.json"), "repo")
	writeFile(t, filepath.Join(rt.Destination, ".config", "app", "config.json"), "home")
	writeFile(t, filepath.Join(rt.Destination, ".config", "app", ".gitignore"), "generated")
	writeFile(t, filepath.Join(rt.Destination, ".config", "app", ".git", "config"), "git")
	linkPath := filepath.Join(rt.Destination, ".config", "app", "system-link")
	if err := os.Symlink("/nix/store/icon", linkPath); err != nil {
		t.Fatal(err)
	}

	actions, err := Run(rt, Options{})
	if err != nil {
		t.Fatal(err)
	}

	assertHasAction(t, actions, "M", filepath.Join(rt.Destination, ".config", "app", "config.json"))
	assertNoAction(t, actions, filepath.Join(rt.Destination, ".config", "app", ".gitignore"))
	assertNoAction(t, actions, filepath.Join(rt.Destination, ".config", "app", ".git", "config"))
	assertNoAction(t, actions, linkPath)
	if _, err := os.Lstat(filepath.Join(rt.Destination, ".config", "app", ".gitignore")); err != nil {
		t.Fatalf(".gitignore should be preserved: %v", err)
	}
	if _, err := os.Lstat(linkPath); err != nil {
		t.Fatalf("symlink should be preserved: %v", err)
	}
}

func TestRunCopiesSharedPathsWhenHostIsUnknown(t *testing.T) {
	rt := testRuntime(t)
	rt.Config.Hosts = map[string]dotconfig.PathList{
		"lenovo": {Paths: []string{".config/fish/host-lenovo.fish"}},
	}
	writeFile(t, filepath.Join(rt.SourceShared, ".config", "app", "config.json"), "shared")
	writeFile(t, filepath.Join(rt.HostSource("lenovo"), ".config", "fish", "host-lenovo.fish"), "host")

	actions, err := Run(rt, Options{Host: "unlisted"})
	if err != nil {
		t.Fatal(err)
	}

	assertHasAction(t, actions, "A", filepath.Join(rt.Destination, ".config", "app", "config.json"))
	assertNoAction(t, actions, filepath.Join(rt.Destination, ".config", "fish", "host-lenovo.fish"))
	content, err := os.ReadFile(filepath.Join(rt.Destination, ".config", "app", "config.json"))
	if err != nil {
		t.Fatal(err)
	}
	if string(content) != "shared" {
		t.Fatalf("shared content = %q, want shared", string(content))
	}
	assertNotExists(t, filepath.Join(rt.Destination, ".config", "fish", "host-lenovo.fish"))
}

func TestRunTargetCopiesOnlyRequestedManagedFile(t *testing.T) {
	rt := testRuntime(t)
	writeFile(t, filepath.Join(rt.SourceShared, ".config", "app", "one.txt"), "repo one")
	writeFile(t, filepath.Join(rt.SourceShared, ".config", "app", "two.txt"), "repo two")
	writeFile(t, filepath.Join(rt.Destination, ".config", "app", "one.txt"), "home one")
	writeFile(t, filepath.Join(rt.Destination, ".config", "app", "two.txt"), "home two")

	actions, err := Run(rt, Options{Target: ".config/app/one.txt"})
	if err != nil {
		t.Fatal(err)
	}

	one := filepath.Join(rt.Destination, ".config", "app", "one.txt")
	two := filepath.Join(rt.Destination, ".config", "app", "two.txt")
	assertHasAction(t, actions, "M", one)
	assertNoAction(t, actions, two)
	content, err := os.ReadFile(two)
	if err != nil {
		t.Fatal(err)
	}
	if string(content) != "home two" {
		t.Fatalf("unrequested file content = %q, want home two", string(content))
	}
}

func TestRunTargetRejectsPathOutsideManifest(t *testing.T) {
	rt := testRuntime(t)
	writeFile(t, filepath.Join(rt.SourceShared, ".config", "other", "config.json"), "repo")

	_, err := Run(rt, Options{Target: ".config/other/config.json"})
	if err == nil {
		t.Fatal("expected unmanaged target error")
	}
}

func TestRunSeedsMissingLocalDefaultWithoutOverwritingExistingLocalFile(t *testing.T) {
	rt := testRuntime(t)
	rt.Config.Shared.Paths = []string{".config/rofi"}
	rt.Config.LocalOnly.Paths = []string{".config/rofi/orgm-current.rasi"}
	rt.Config.LocalDefaults.Paths = []string{".config/rofi/orgm-current.rasi"}
	defaultPath := filepath.Join(rt.SourceShared, ".config", "rofi", "orgm-current.rasi")
	dstPath := filepath.Join(rt.Destination, ".config", "rofi", "orgm-current.rasi")
	writeFile(t, defaultPath, "repo default")

	actions, err := Run(rt, Options{})
	if err != nil {
		t.Fatal(err)
	}

	assertHasAction(t, actions, "A", dstPath)
	content, err := os.ReadFile(dstPath)
	if err != nil {
		t.Fatal(err)
	}
	if string(content) != "repo default" {
		t.Fatalf("seeded content = %q, want repo default", string(content))
	}

	actions, err = Run(rt, Options{})
	if err != nil {
		t.Fatal(err)
	}
	assertNoAction(t, actions, dstPath)

	writeFile(t, dstPath, "local theme")
	actions, err = Run(rt, Options{})
	if err != nil {
		t.Fatal(err)
	}
	assertNoAction(t, actions, dstPath)
	content, err = os.ReadFile(dstPath)
	if err != nil {
		t.Fatal(err)
	}
	if string(content) != "local theme" {
		t.Fatalf("local content = %q, want local theme", string(content))
	}
}

func testRuntime(t *testing.T) dotconfig.Runtime {
	t.Helper()
	root := t.TempDir()
	repo := filepath.Join(root, "repo")
	home := filepath.Join(root, "home")
	shared := filepath.Join(repo, "config", "shared")
	hosts := filepath.Join(repo, "config", "hosts")
	state := filepath.Join(root, "state")
	if err := os.MkdirAll(shared, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(home, 0o755); err != nil {
		t.Fatal(err)
	}
	return dotconfig.Runtime{
		Repo:         repo,
		Destination:  home,
		SourceShared: shared,
		SourceHosts:  hosts,
		StateDir:     state,
		Config: dotconfig.Config{
			Shared: dotconfig.PathList{Paths: []string{".config/app"}},
			LocalOnly: dotmanifest.LocalOnlyRules{
				Patterns: []string{"**/.git", "**/.git/**", "**/.gitignore"},
				Types:    []string{"symlink"},
			},
		},
	}
}

func writeFile(t *testing.T, path, content string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
}

func assertHasAction(t *testing.T, actions []Action, code, path string) {
	t.Helper()
	for _, action := range actions {
		if action.Code == code && action.Path == path {
			return
		}
	}
	t.Fatalf("missing %s action for %s in %#v", code, path, actions)
}

func assertNoAction(t *testing.T, actions []Action, path string) {
	t.Helper()
	for _, action := range actions {
		if action.Path == path {
			t.Fatalf("unexpected action for %s: %#v", path, action)
		}
	}
}

func assertNotExists(t *testing.T, path string) {
	t.Helper()
	if _, err := os.Lstat(path); err == nil {
		t.Fatalf("%s should not exist", path)
	} else if !os.IsNotExist(err) {
		t.Fatalf("checking %s: %v", path, err)
	}
}

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

func TestShouldSyncPathForHyprlandAllowsHyprlandAndBlocksOtherDesktopHelpers(t *testing.T) {
	allowed := []string{".config/hypr", ".config/hypr/hyprland.conf", ".config/swaync", ".local/bin/hypr-main-menu"}
	for _, rel := range allowed {
		if !shouldSyncPath(DesktopHyprland, rel) {
			t.Fatalf("hyprland should allow %s", rel)
		}
	}

	blocked := []string{".config/labwc", ".config/sway", ".config/swaylock", ".local/bin/labwc-kill-windows", ".local/bin/sway-app-dock"}
	for _, rel := range blocked {
		if shouldSyncPath(DesktopHyprland, rel) {
			t.Fatalf("hyprland should block %s", rel)
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
	assertNotExists(t, filepath.Join(rt.Destination, ".config", "hypr"))
	assertNotExists(t, filepath.Join(rt.Destination, ".config", "hypr", "hyprland.conf"))
	assertNotExists(t, filepath.Join(rt.Destination, ".local", "bin", "hypr-main-menu"))
}

func TestRunFiltersDesktopSpecificFilesInsideAllowedDirectory(t *testing.T) {
	t.Setenv("ORGM_DOT_DESKTOP", "gnome")
	rt := testRuntime(t)
	rt.Config.Shared.Paths = []string{".config/rofi"}
	writeFile(t, filepath.Join(rt.SourceShared, ".config", "rofi", "config.rasi"), "common")
	writeFile(t, filepath.Join(rt.SourceShared, ".config", "rofi", "hypr-menu.env"), "hypr")

	actions, err := Run(rt, Options{})
	if err != nil {
		t.Fatal(err)
	}

	assertHasAction(t, actions, "A", filepath.Join(rt.Destination, ".config", "rofi", "config.rasi"))
	assertNoAction(t, actions, filepath.Join(rt.Destination, ".config", "rofi", "hypr-menu.env"))
	assertNotExists(t, filepath.Join(rt.Destination, ".config", "rofi", "hypr-menu.env"))
}

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
	assertNotExists(t, filepath.Join(rt.Destination, ".config", "rofi", "hypr-menu.env"))
}

func TestRunReturnsInvalidDesktopOverrideError(t *testing.T) {
	t.Setenv("ORGM_DOT_DESKTOP", "plasma")
	rt := testRuntime(t)

	_, err := Run(rt, Options{})
	if err == nil {
		t.Fatal("expected invalid desktop override error")
	}
}

func mapLookup(values map[string]string) func(string) string {
	return func(key string) string {
		return values[key]
	}
}
