package orgmtheme

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// Command is one external command planned by Apply.
type Command struct {
	Name string
	Args []string
}

// CommandRunner executes planned commands without invoking a shell.
type CommandRunner interface {
	RunCommand(Command) error
}

// ApplyOptions controls theme application.
type ApplyOptions struct {
	ThemeName   string
	NoReload    bool
	DryRun      bool
	PrintReload bool
	Env         Env
	Runner      CommandRunner
	StateHome   string
	ThemesDir   string
	Home        string
}

// ApplyResult reports files and commands planned during Apply.
type ApplyResult struct {
	ThemeName string
	Writes    []PlannedWrite
	Commands  []Command
}

// Apply writes active theme files, persists current theme state, remembers the
// outgoing wallpaper, then restores any wallpaper saved for the incoming theme.
func Apply(options ApplyOptions) (ApplyResult, error) {
	paths, err := resolveApplyPaths(options)
	if err != nil {
		return ApplyResult{}, err
	}
	if options.ThemeName != "orgm-dark" && options.ThemeName != "orgm-light" {
		return ApplyResult{}, fmt.Errorf("theme must be orgm-dark or orgm-light")
	}
	theme, err := LoadTheme(paths.themesDir, options.ThemeName)
	if err != nil {
		return ApplyResult{}, err
	}
	renderedWrites, err := BuildWrites(options.Env, theme)
	if err != nil {
		return ApplyResult{}, err
	}
	themeEnv, err := os.ReadFile(filepath.Join(paths.themesDir, options.ThemeName+".env"))
	if err != nil {
		return ApplyResult{}, err
	}

	stateDir := filepath.Join(paths.stateHome, "orgm-theme")
	currentFile := filepath.Join(stateDir, "current")
	previousTheme := readTrimmedFile(currentFile)
	if !options.DryRun {
		if err := saveCurrentWallpaperForTheme(paths.stateHome, previousTheme); err != nil {
			return ApplyResult{}, err
		}
	}

	writes := append([]PlannedWrite{
		{Path: filepath.Join(stateDir, "current.env"), Content: string(themeEnv)},
		{Path: currentFile, Content: theme.Name + "\n"},
	}, renderedWrites...)
	if !options.DryRun {
		for _, write := range writes {
			if err := atomicWriteString(write.Path, write.Content, 0o644); err != nil {
				return ApplyResult{}, err
			}
		}
	}

	commands := make([]Command, 0)
	if !options.NoReload {
		commands = append(commands, liveReloadCommands()...)
	}
	commands = append(commands, restoreWallpaperCommands(paths.stateHome, theme.Name)...)
	if !options.DryRun {
		runner := options.Runner
		if runner == nil {
			runner = osCommandRunner{}
		}
		for _, command := range commands {
			_ = runner.RunCommand(command)
		}
	}

	return ApplyResult{ThemeName: theme.Name, Writes: writes, Commands: commands}, nil
}

type applyPaths struct {
	home      string
	themesDir string
	stateHome string
}

func resolveApplyPaths(options ApplyOptions) (applyPaths, error) {
	if options.ThemeName == "" {
		return applyPaths{}, fmt.Errorf("theme name is required")
	}
	themesDir := options.ThemesDir
	if themesDir == "" {
		themesDir = filepath.Join(options.Env.ConfigHome, "orgm-theme", "themes")
	}
	stateHome := options.StateHome
	if stateHome == "" {
		switch {
		case options.Home != "":
			stateHome = filepath.Join(options.Home, ".local", "state")
		case options.Env.DataHome != "":
			stateHome = filepath.Join(filepath.Dir(options.Env.DataHome), "state")
		}
	}
	home := options.Home
	if home == "" && strings.HasSuffix(options.Env.ConfigHome, string(filepath.Separator)+".config") {
		home = filepath.Dir(options.Env.ConfigHome)
	}
	if themesDir == "" || !filepath.IsAbs(themesDir) {
		return applyPaths{}, fmt.Errorf("ThemesDir must be an absolute path")
	}
	if stateHome == "" || !filepath.IsAbs(stateHome) {
		return applyPaths{}, fmt.Errorf("StateHome must be an absolute path")
	}
	return applyPaths{home: home, themesDir: themesDir, stateHome: stateHome}, nil
}

type osCommandRunner struct{}

func (osCommandRunner) RunCommand(command Command) error {
	cmd := exec.Command(command.Name, command.Args...)
	if err := cmd.Run(); err != nil {
		if errors.Is(err, exec.ErrNotFound) || strings.Contains(err.Error(), "executable file not found") {
			return nil
		}
		return err
	}
	return nil
}

func saveCurrentWallpaperForTheme(stateHome, themeName string) error {
	if strings.TrimSpace(themeName) == "" {
		return nil
	}
	if err := validateThemeName(themeName); err != nil {
		return nil
	}
	wallpaperState := filepath.Join(stateHome, "hypr-wallpaper", "state")
	values := readStateFile(wallpaperState)
	path := values["path"]
	if path == "" {
		return nil
	}
	mode := values["mode"]
	if mode == "" {
		mode = "static"
	}
	wallpaperDir := filepath.Join(stateHome, "orgm-theme", "wallpapers")
	if err := atomicWriteString(filepath.Join(wallpaperDir, themeName+".state"), fmt.Sprintf("mode=%s\npath=%s\n", mode, path), 0o644); err != nil {
		return err
	}
	return saveMonitorWallpaperStates(stateHome, themeName)
}

func saveMonitorWallpaperStates(stateHome, themeName string) error {
	monitorStateDir := filepath.Join(stateHome, "hypr-wallpaper", "monitors")
	entries, err := os.ReadDir(monitorStateDir)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return nil
		}
		return err
	}
	outDir := filepath.Join(stateHome, "orgm-theme", "wallpapers", themeName+".monitors")
	if err := os.RemoveAll(outDir); err != nil {
		return err
	}
	for _, entry := range entries {
		if entry.IsDir() || filepath.Ext(entry.Name()) != ".state" {
			continue
		}
		content, err := os.ReadFile(filepath.Join(monitorStateDir, entry.Name()))
		if err != nil {
			return err
		}
		if err := AtomicWriteFile(filepath.Join(outDir, entry.Name()), content, 0o644); err != nil {
			return err
		}
	}
	return nil
}

func restoreWallpaperCommands(stateHome, themeName string) []Command {
	wallpaperDir := filepath.Join(stateHome, "orgm-theme", "wallpapers")
	saved := filepath.Join(wallpaperDir, themeName+".state")
	values := readStateFile(saved)
	path := values["path"]
	if path == "" {
		return nil
	}
	if strings.HasPrefix(values["mode"], "video") {
		return []Command{{Name: "orgm-wallpaper", Args: []string{"set-video", path}}}
	}
	monitorCommands := monitorWallpaperCommands(filepath.Join(wallpaperDir, themeName+".monitors"))
	if len(monitorCommands) > 0 {
		return monitorCommands
	}
	return []Command{{Name: "orgm-wallpaper", Args: []string{"set-static", path}}}
}

func monitorWallpaperCommands(dir string) []Command {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil
	}
	commands := make([]Command, 0, len(entries))
	for _, entry := range entries {
		if entry.IsDir() || filepath.Ext(entry.Name()) != ".state" {
			continue
		}
		values := readStateFile(filepath.Join(dir, entry.Name()))
		path := values["path"]
		if path == "" {
			continue
		}
		output := strings.TrimSuffix(entry.Name(), ".state")
		command := "set-static"
		if strings.HasPrefix(values["mode"], "video") {
			command = "set-video"
		}
		commands = append(commands, Command{Name: "orgm-wallpaper", Args: []string{command, path, "--monitor", output}})
	}
	return commands
}

func liveReloadCommands() []Command {
	return []Command{
		{Name: "hyprctl", Args: []string{"reload"}},
		{Name: "swaync-client", Args: []string{"-rs"}},
	}
}

func readStateFile(path string) map[string]string {
	content, err := os.ReadFile(path)
	if err != nil {
		return map[string]string{}
	}
	values := make(map[string]string)
	for _, line := range strings.Split(string(content), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		key, value, ok := strings.Cut(line, "=")
		if ok {
			values[strings.TrimSpace(key)] = strings.TrimSpace(value)
		}
	}
	return values
}

func readTrimmedFile(path string) string {
	content, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(content))
}
