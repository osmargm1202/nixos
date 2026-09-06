package orgmtheme

import (
	"errors"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

func TestApplyWritesStateRenderedFilesAndSavesOutgoingWallpapers(t *testing.T) {
	root := t.TempDir()
	paths := newApplyTestPaths(t, root)
	writeTestTheme(t, paths.themesDir, "orgm-light")
	writeTestTheme(t, paths.themesDir, "orgm-dark")
	writeFile(t, filepath.Join(paths.stateHome, "orgm-theme", "current"), "orgm-dark\n")
	writeFile(t, filepath.Join(paths.stateHome, "hypr-wallpaper", "current"), "/wallpapers/dark.png\n")
	writeFile(t, filepath.Join(paths.stateHome, "hypr-wallpaper", "monitors", "DP-1.state"), "mode=static\npath=/wallpapers/dark-dp1.png\n")
	writeFile(t, filepath.Join(paths.stateHome, "hypr-wallpaper", "monitors", "HDMI-A-1.state"), "mode=video\npath=/wallpapers/dark-hdmi.mp4\n")

	runner := &recordingRunner{}
	result, err := Apply(ApplyOptions{
		ThemeName: "orgm-light",
		NoReload:  true,
		Env:       Env{ConfigHome: paths.configHome, DataHome: paths.dataHome},
		StateHome: paths.stateHome,
		ThemesDir: paths.themesDir,
		Home:      paths.home,
		Runner:    runner,
	})
	if err != nil {
		t.Fatalf("Apply error = %v", err)
	}
	if result.ThemeName != "orgm-light" {
		t.Fatalf("Apply result theme = %q, want orgm-light", result.ThemeName)
	}
	assertFileEquals(t, filepath.Join(paths.stateHome, "orgm-theme", "current"), "orgm-light\n")
	assertFileEquals(t, filepath.Join(paths.stateHome, "orgm-theme", "current.env"), validThemeEnv("orgm-light"))
	assertFileContains(t, filepath.Join(paths.configHome, "waybar", "orgm-current.css"), "@define-color text     #111827;")
	assertFileContains(t, filepath.Join(paths.configHome, "quickshell", "theme", "current.json"), `"accent": "#1e66f5"`)
	assertFileContains(t, filepath.Join(paths.configHome, "quickshell", "theme", "theme.json"), `"accent": "#1e66f5"`)
	assertFileEquals(t, filepath.Join(paths.stateHome, "orgm-theme", "wallpapers", "orgm-dark.state"), "path=/wallpapers/dark.png\n")
	assertFileEquals(t, filepath.Join(paths.stateHome, "orgm-theme", "wallpapers", "orgm-dark.monitors", "DP-1.state"), "mode=static\npath=/wallpapers/dark-dp1.png\n")
	assertFileEquals(t, filepath.Join(paths.stateHome, "orgm-theme", "wallpapers", "orgm-dark.monitors", "HDMI-A-1.state"), "mode=video\npath=/wallpapers/dark-hdmi.mp4\n")
	if len(runner.commands) != 0 {
		t.Fatalf("runner commands = %#v, want none without incoming wallpaper/reload", runner.commands)
	}
}

func TestApplyRemovesStaleOutgoingMonitorSnapshots(t *testing.T) {
	root := t.TempDir()
	paths := newApplyTestPaths(t, root)
	writeTestTheme(t, paths.themesDir, "orgm-light")
	writeFile(t, filepath.Join(paths.stateHome, "orgm-theme", "current"), "orgm-dark\n")
	writeFile(t, filepath.Join(paths.stateHome, "hypr-wallpaper", "current"), "/wallpapers/dark.png\n")
	staleMonitors := filepath.Join(paths.stateHome, "orgm-theme", "wallpapers", "orgm-dark.monitors")
	writeFile(t, filepath.Join(staleMonitors, "DP-1.state"), "mode=static\npath=/wallpapers/stale.png\n")

	_, err := Apply(ApplyOptions{
		ThemeName: "orgm-light",
		NoReload:  true,
		Env:       Env{ConfigHome: paths.configHome, DataHome: paths.dataHome},
		StateHome: paths.stateHome,
		ThemesDir: paths.themesDir,
		Home:      paths.home,
		Runner:    &recordingRunner{},
	})
	if err != nil {
		t.Fatalf("Apply error = %v", err)
	}
	if _, err := os.Stat(staleMonitors); !os.IsNotExist(err) {
		t.Fatalf("stale monitor snapshots stat error = %v, want not exist", err)
	}
}

func TestApplyRejectsNonPresetThemeNames(t *testing.T) {
	root := t.TempDir()
	paths := newApplyTestPaths(t, root)
	writeTestTheme(t, paths.themesDir, "custom-theme")

	_, err := Apply(ApplyOptions{
		ThemeName: "custom-theme",
		NoReload:  true,
		Env:       Env{ConfigHome: paths.configHome, DataHome: paths.dataHome},
		StateHome: paths.stateHome,
		ThemesDir: paths.themesDir,
		Home:      paths.home,
	})
	if err == nil {
		t.Fatal("Apply accepted custom-theme, want only orgm-dark/orgm-light")
	}
}

func TestApplySkipsInvalidPersistedPreviousThemeName(t *testing.T) {
	root := t.TempDir()
	paths := newApplyTestPaths(t, root)
	writeTestTheme(t, paths.themesDir, "orgm-light")
	writeFile(t, filepath.Join(paths.stateHome, "orgm-theme", "current"), "../evil\n")
	writeFile(t, filepath.Join(paths.stateHome, "hypr-wallpaper", "current"), "/wallpapers/dark.png\n")

	_, err := Apply(ApplyOptions{
		ThemeName: "orgm-light",
		NoReload:  true,
		Env:       Env{ConfigHome: paths.configHome, DataHome: paths.dataHome},
		StateHome: paths.stateHome,
		ThemesDir: paths.themesDir,
		Home:      paths.home,
		Runner:    &recordingRunner{},
	})
	if err != nil {
		t.Fatalf("Apply error = %v, want invalid previous theme skipped", err)
	}
	outside := filepath.Join(paths.stateHome, "orgm-theme", "evil.state")
	if _, err := os.Stat(outside); !os.IsNotExist(err) {
		t.Fatalf("outside state stat error = %v, want not exist", err)
	}
}

func TestApplyRestoresIncomingGlobalAndMonitorWallpapersAfterWrites(t *testing.T) {
	root := t.TempDir()
	paths := newApplyTestPaths(t, root)
	writeTestTheme(t, paths.themesDir, "orgm-light")
	writeFile(t, filepath.Join(paths.stateHome, "orgm-theme", "wallpapers", "orgm-light.state"), "mode=static\npath=/wallpapers/light-fallback.png\n")
	writeFile(t, filepath.Join(paths.stateHome, "orgm-theme", "wallpapers", "orgm-light.monitors", "DP-1.state"), "mode=static\npath=/wallpapers/light-dp1.png\n")
	writeFile(t, filepath.Join(paths.stateHome, "orgm-theme", "wallpapers", "orgm-light.monitors", "eDP-1.state"), "mode=video\npath=/wallpapers/live-edp.mp4\n")

	runner := &recordingRunner{t: t, onRun: func(t *testing.T, _ Command) {
		assertFileEquals(t, filepath.Join(paths.stateHome, "orgm-theme", "current"), "orgm-light\n")
	}}
	_, err := Apply(ApplyOptions{
		ThemeName: "orgm-light",
		NoReload:  true,
		Env:       Env{ConfigHome: paths.configHome, DataHome: paths.dataHome},
		StateHome: paths.stateHome,
		ThemesDir: paths.themesDir,
		Home:      paths.home,
		Runner:    runner,
	})
	if err != nil {
		t.Fatalf("Apply error = %v", err)
	}
	want := []Command{
		{Name: "hypr-wallpaper", Args: []string{"set", "/wallpapers/light-fallback.png"}},
		{Name: "hypr-wallpaper", Args: []string{"set", "/wallpapers/light-dp1.png", "--monitor", "DP-1"}},
		{Name: "hypr-wallpaper", Args: []string{"set", "/wallpapers/live-edp.mp4", "--monitor", "eDP-1"}},
	}
	if !reflect.DeepEqual(runner.commands, want) {
		t.Fatalf("runner commands = %#v, want %#v", runner.commands, want)
	}
}

func TestApplyRestoresIncomingVideoAndSingleGlobalWallpaper(t *testing.T) {
	for _, tc := range []struct {
		name        string
		state       string
		wantCommand Command
	}{
		{
			name:        "video",
			state:       "mode=video\npath=/wallpapers/light.mp4\n",
			wantCommand: Command{Name: "hypr-wallpaper", Args: []string{"set", "/wallpapers/light.mp4"}},
		},
		{
			name:        "single static fallback",
			state:       "mode=static\npath=/wallpapers/light.png\n",
			wantCommand: Command{Name: "hypr-wallpaper", Args: []string{"set", "/wallpapers/light.png"}},
		},
	} {
		t.Run(tc.name, func(t *testing.T) {
			root := t.TempDir()
			paths := newApplyTestPaths(t, root)
			writeTestTheme(t, paths.themesDir, "orgm-light")
			writeFile(t, filepath.Join(paths.stateHome, "orgm-theme", "wallpapers", "orgm-light.state"), tc.state)

			runner := &recordingRunner{}
			_, err := Apply(ApplyOptions{
				ThemeName: "orgm-light",
				NoReload:  true,
				Env:       Env{ConfigHome: paths.configHome, DataHome: paths.dataHome},
				StateHome: paths.stateHome,
				ThemesDir: paths.themesDir,
				Home:      paths.home,
				Runner:    runner,
			})
			if err != nil {
				t.Fatalf("Apply error = %v", err)
			}
			want := []Command{tc.wantCommand}
			if !reflect.DeepEqual(runner.commands, want) {
				t.Fatalf("runner commands = %#v, want %#v", runner.commands, want)
			}
		})
	}
}

func TestApplyReloadsThemeTargetsBeforeRestoringWallpapers(t *testing.T) {
	root := t.TempDir()
	paths := newApplyTestPaths(t, root)
	writeTestTheme(t, paths.themesDir, "orgm-light")
	writeFile(t, filepath.Join(paths.stateHome, "orgm-theme", "wallpapers", "orgm-light.state"), "path=/wallpapers/light.png\n")
	writeFile(t, filepath.Join(paths.stateHome, "orgm-theme", "wallpapers", "orgm-light.monitors", "DP-1.state"), "mode=static\npath=/wallpapers/light-dp.png\n")

	runner := &recordingRunner{}
	_, err := Apply(ApplyOptions{
		ThemeName: "orgm-light",
		Env:       Env{ConfigHome: paths.configHome, DataHome: paths.dataHome},
		StateHome: paths.stateHome,
		ThemesDir: paths.themesDir,
		Home:      paths.home,
		Runner:    runner,
	})
	if err != nil {
		t.Fatalf("Apply error = %v", err)
	}
	want := []Command{
		{Name: "hyprctl", Args: []string{"reload"}},
		{Name: "swaync-client", Args: []string{"-rs"}},
		{Name: "hypr-wallpaper", Args: []string{"set", "/wallpapers/light.png"}},
		{Name: "hypr-wallpaper", Args: []string{"set", "/wallpapers/light-dp.png", "--monitor", "DP-1"}},
	}
	if !reflect.DeepEqual(runner.commands, want) {
		t.Fatalf("runner commands = %#v, want %#v", runner.commands, want)
	}
}

func TestApplyTreatsLiveReloadCommandErrorsAsBestEffort(t *testing.T) {
	root := t.TempDir()
	paths := newApplyTestPaths(t, root)
	writeTestTheme(t, paths.themesDir, "orgm-light")

	runner := &recordingRunner{returnError: errors.New("reload target unavailable")}
	result, err := Apply(ApplyOptions{
		ThemeName: "orgm-light",
		Env:       Env{ConfigHome: paths.configHome, DataHome: paths.dataHome},
		StateHome: paths.stateHome,
		ThemesDir: paths.themesDir,
		Home:      paths.home,
		Runner:    runner,
	})
	if err != nil {
		t.Fatalf("Apply error = %v, want best-effort command errors ignored", err)
	}
	if len(result.Commands) == 0 || len(runner.commands) == 0 {
		t.Fatalf("commands result=%#v runner=%#v, want live reload commands attempted", result.Commands, runner.commands)
	}
}

func TestApplyDoesNotMutatePiSettings(t *testing.T) {
	root := t.TempDir()
	paths := newApplyTestPaths(t, root)
	writeTestTheme(t, paths.themesDir, "orgm-light")
	settingsPath := filepath.Join(paths.home, ".pi", "agent", "settings.json")
	writeFile(t, settingsPath, "{\"other\":true,\"theme\":\"old\"}\n")

	_, err := Apply(ApplyOptions{
		ThemeName: "orgm-light",
		NoReload:  true,
		Env:       Env{ConfigHome: paths.configHome, DataHome: paths.dataHome},
		StateHome: paths.stateHome,
		ThemesDir: paths.themesDir,
		Home:      paths.home,
	})
	if err != nil {
		t.Fatalf("Apply error = %v", err)
	}
	assertFileEquals(t, settingsPath, "{\"other\":true,\"theme\":\"old\"}\n")

	missingRoot := t.TempDir()
	missingPaths := newApplyTestPaths(t, missingRoot)
	writeTestTheme(t, missingPaths.themesDir, "orgm-light")
	missingSettings := filepath.Join(missingPaths.home, ".pi", "agent", "settings.json")
	_, err = Apply(ApplyOptions{
		ThemeName: "orgm-light",
		NoReload:  true,
		Env:       Env{ConfigHome: missingPaths.configHome, DataHome: missingPaths.dataHome},
		StateHome: missingPaths.stateHome,
		ThemesDir: missingPaths.themesDir,
		Home:      missingPaths.home,
	})
	if err != nil {
		t.Fatalf("Apply with missing Pi settings error = %v", err)
	}
	if _, err := os.Stat(missingSettings); !os.IsNotExist(err) {
		t.Fatalf("missing settings stat error = %v, want not exist", err)
	}
}

type applyTestPaths struct {
	home       string
	configHome string
	dataHome   string
	stateHome  string
	themesDir  string
}

func newApplyTestPaths(t *testing.T, root string) applyTestPaths {
	t.Helper()
	paths := applyTestPaths{
		home:       filepath.Join(root, "home"),
		configHome: filepath.Join(root, "config"),
		dataHome:   filepath.Join(root, "data"),
		stateHome:  filepath.Join(root, "state"),
	}
	paths.themesDir = filepath.Join(paths.configHome, "orgm-theme", "themes")
	if err := os.MkdirAll(paths.themesDir, 0o755); err != nil {
		t.Fatal(err)
	}
	return paths
}

type recordingRunner struct {
	t           *testing.T
	commands    []Command
	onRun       func(*testing.T, Command)
	returnError error
}

func (r *recordingRunner) RunCommand(command Command) error {
	r.commands = append(r.commands, command)
	if r.onRun != nil {
		r.onRun(r.t, command)
	}
	return r.returnError
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

func assertFileEquals(t *testing.T, path, want string) {
	t.Helper()
	content, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("ReadFile(%s) error = %v", path, err)
	}
	if string(content) != want {
		t.Fatalf("%s = %q, want %q", path, string(content), want)
	}
}

func assertFileContains(t *testing.T, path, want string) {
	t.Helper()
	content, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("ReadFile(%s) error = %v", path, err)
	}
	if !strings.Contains(string(content), want) {
		t.Fatalf("%s = %q, want substring %q", path, string(content), want)
	}
}
