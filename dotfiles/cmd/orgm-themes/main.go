package main

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/osmargm1202/nixos/internal/cli"
	"github.com/osmargm1202/nixos/internal/orgmtheme"
)

func main() {
	if err := run(os.Args[1:]); err != nil {
		os.Exit(cli.PrintError(os.Stderr, err))
	}
}

func run(args []string) error {
	return runWithIO(args, os.Stdout, os.Stderr, osEnvMap())
}

func runWithIO(args []string, stdout, stderr io.Writer, env map[string]string) error {
	paths := pathsFromEnv(env)
	if len(args) < 1 {
		return cli.UsageError(usage())
	}
	if len(args) > 1 && (args[0] == "list" || args[0] == "current" || args[0] == "status") {
		return cli.UsageError("unexpected argument: %s", args[1])
	}

	switch args[0] {
	case "list":
		themes, err := orgmtheme.ListThemes(paths.themesDir)
		if err != nil {
			return err
		}
		for _, theme := range themes {
			fmt.Fprintln(stdout, theme)
		}
		return nil
	case "current":
		fmt.Fprintln(stdout, currentTheme(paths.currentFile))
		return nil
	case "status":
		name := currentTheme(paths.currentFile)
		theme, err := orgmtheme.LoadTheme(paths.themesDir, name)
		if err != nil {
			return err
		}
		fmt.Fprintf(stdout, "Theme: %s\nGTK: %s\nIcons: %s\nCursor: %s %s\nColor scheme: %s\nPi theme: %s\n", theme.Name, theme.GTKTheme, theme.IconTheme, theme.CursorTheme, theme.CursorSize, theme.ColorScheme, theme.PITheme)
		return nil
	case "apply":
		options, err := applyOptionsFromArgs(args[1:], paths)
		if err != nil {
			return err
		}
		result, err := orgmtheme.Apply(options)
		if err != nil {
			return err
		}
		printApplied(stdout, result)
		return nil
	case "toggle":
		noReload, dryRun, printReload, err := toggleOptionsFromArgs(args[1:])
		if err != nil {
			return err
		}
		name := "orgm-light"
		if currentTheme(paths.currentFile) == "orgm-light" {
			name = "orgm-dark"
		}
		result, err := orgmtheme.Apply(applyOptions(paths, name, noReload, dryRun, printReload))
		if err != nil {
			return err
		}
		printApplied(stdout, result)
		return nil
	case "-h", "--help", "help":
		fmt.Fprintln(stdout, usage())
		return nil
	default:
		return cli.UsageError(usage())
	}
}

type themePaths struct {
	home        string
	configHome  string
	dataHome    string
	stateHome   string
	themesDir   string
	currentFile string
}

func pathsFromEnv(env map[string]string) themePaths {
	home := env["HOME"]
	configHome := env["XDG_CONFIG_HOME"]
	if configHome == "" {
		configHome = filepath.Join(home, ".config")
	}
	stateHome := env["XDG_STATE_HOME"]
	if stateHome == "" {
		stateHome = filepath.Join(home, ".local", "state")
	}
	dataHome := env["XDG_DATA_HOME"]
	if dataHome == "" {
		dataHome = filepath.Join(home, ".local", "share")
	}
	themesDir := env["ORGM_THEMES_DIR"]
	if themesDir == "" {
		themesDir = filepath.Join(configHome, "orgm-theme", "themes")
	}
	return themePaths{
		home:        home,
		configHome:  configHome,
		dataHome:    dataHome,
		stateHome:   stateHome,
		themesDir:   themesDir,
		currentFile: filepath.Join(stateHome, "orgm-theme", "current"),
	}
}

func currentTheme(path string) string {
	content, err := os.ReadFile(path)
	if err != nil {
		return "orgm-dark"
	}
	name := strings.TrimSpace(string(content))
	if name == "" {
		return "orgm-dark"
	}
	return name
}

func applyOptionsFromArgs(args []string, paths themePaths) (orgmtheme.ApplyOptions, error) {
	if len(args) < 1 {
		return orgmtheme.ApplyOptions{}, cli.UsageError("usage: orgm-themes apply THEME [--no-reload]")
	}
	themeName := args[0]
	noReload := false
	dryRun := false
	printReload := false
	for _, arg := range args[1:] {
		switch arg {
		case "--no-reload":
			noReload = true
		case "--dry-run":
			dryRun = true
		case "--print-reload":
			printReload = true
		default:
			return orgmtheme.ApplyOptions{}, cli.UsageError("unexpected apply argument: %s", arg)
		}
	}
	return applyOptions(paths, themeName, noReload, dryRun, printReload), nil
}

func toggleOptionsFromArgs(args []string) (noReload, dryRun, printReload bool, err error) {
	for _, arg := range args {
		switch arg {
		case "--no-reload":
			noReload = true
		case "--dry-run":
			dryRun = true
		case "--print-reload":
			printReload = true
		default:
			return false, false, false, cli.UsageError("unexpected toggle argument: %s", arg)
		}
	}
	return noReload, dryRun, printReload, nil
}

func applyOptions(paths themePaths, themeName string, noReload, dryRun, printReload bool) orgmtheme.ApplyOptions {
	return orgmtheme.ApplyOptions{
		ThemeName:   themeName,
		NoReload:    noReload,
		DryRun:      dryRun,
		PrintReload: printReload,
		Env:         orgmtheme.Env{ConfigHome: paths.configHome, DataHome: paths.dataHome},
		StateHome:   paths.stateHome,
		ThemesDir:   paths.themesDir,
		Home:        paths.home,
	}
}

func printApplied(stdout io.Writer, result orgmtheme.ApplyResult) {
	fmt.Fprintf(stdout, "Applied %s\n", result.ThemeName)
}

func osEnvMap() map[string]string {
	env := make(map[string]string)
	for _, item := range os.Environ() {
		key, value, ok := strings.Cut(item, "=")
		if ok {
			env[key] = value
		}
	}
	return env
}

func usage() string {
	return `usage: orgm-themes <command> [theme]

commands:
  list              list available themes
  current           print current theme
  status            show current theme and key toolkit settings
  apply THEME [--no-reload]
                    apply theme
  toggle [--no-reload]
                    toggle orgm-dark/orgm-light`
}
