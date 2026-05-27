package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/osmargm1202/nixos/internal/calendar"
	"github.com/osmargm1202/nixos/internal/cli"
	"github.com/osmargm1202/nixos/internal/dock"
	"github.com/osmargm1202/nixos/internal/helper"
	"github.com/osmargm1202/nixos/internal/menu"
	"github.com/osmargm1202/nixos/internal/osd"
	"github.com/osmargm1202/nixos/internal/session"
	"github.com/osmargm1202/nixos/internal/smartrun"
	"github.com/osmargm1202/nixos/internal/theme"
	"github.com/osmargm1202/nixos/internal/wallpaper"
	"github.com/osmargm1202/nixos/internal/waybar"
	"github.com/osmargm1202/nixos/internal/webapp"
	"github.com/osmargm1202/nixos/internal/windows"
	"github.com/osmargm1202/nixos/internal/zen"
)

func main() {
	if err := run(os.Args[1:]); err != nil {
		os.Exit(cli.PrintError(os.Stderr, err))
	}
}

func run(args []string) error {
	return runWithIO(args, os.Stdout, os.Stderr)
}

func runWithIO(args []string, stdout, stderr io.Writer) error {
	if len(args) < 1 {
		return cli.UsageError(usage())
	}

	switch args[0] {
	case "version":
		fmt.Fprintln(stdout, "orgm-hypr dev")
		return nil
	case "wallpaper":
		return runWallpaperWithIO(args[1:], stdout, stderr)
	case "theme":
		return runThemeWithIO(args[1:], stdout, stderr)
	case "session":
		return runSessionWithIO(args[1:], stdout, stderr)
	case "waybar":
		return runWaybarWithIO(args[1:], stdout, stderr)
	case "calendar":
		return calendar.Run(args[1:], stdout, stderr)
	case "dock":
		return runDockWithIO(args[1:], stdout, stderr)
	case "windows":
		return runWindowsWithIO(args[1:], stdout, stderr)
	case "zen":
		return runZenWithIO(args[1:], stdout, stderr)
	case "osd":
		return runOSDWithIO(args[1:], stdout, stderr)
	case "smart-run":
		return runSmartRunWithIO(args[1:], stdout, stderr)
	case "menu":
		return runMenuWithIO(args[1:], stdout, stderr)
	case "helper":
		return helper.Run(args[1:], stdout, stderr)
	case "webapp":
		return runWebappWithIO(args[1:], stdout, stderr)
	case "launcher", "fuzzel":
		return runLauncherWithIO(args[1:], stdout, stderr)
	case "notify":
		return runNotifyWithIO(args[1:], stdout, stderr)
	case "file":
		return runFileWithIO(args[1:], stdout, stderr)
	case "ssh":
		return runSSHWithIO(args[1:], stdout, stderr)
	case "tmux":
		return runTmuxWithIO(args[1:], stdout, stderr)
	case "calc":
		return runCalcWithIO(args[1:], stdout, stderr)
	case "pi":
		return runPiWithIO(args[1:], stdout, stderr)
	case "obsidian":
		return runObsidianWithIO(args[1:], stdout, stderr)
	case "updates":
		return cli.UsageError("%s: command group not implemented yet", args[0])
	default:
		return cli.UsageError(usage())
	}
}

func runThemeWithIO(args []string, stdout, stderr io.Writer) error {
	return runThemeWithEnv(args, stdout, stderr, defaultThemeCommandEnv())
}

func runThemeWithEnv(args []string, stdout, stderr io.Writer, env themeCommandEnv) error {
	if len(args) < 1 {
		return cli.UsageError("usage: orgm-hypr theme [list|validate|status|preview|apply|export-neutral]")
	}
	opts, err := parseThemeFlags(args[1:], env.RegistryPath)
	if err != nil {
		return cli.UsageError(err.Error())
	}

	registry, err := theme.LoadRegistry(opts.registryPath)
	if err != nil {
		return err
	}

	switch args[0] {
	case "list":
		if len(opts.positionals) != 0 || opts.dryRun || opts.mode != "" {
			return cli.UsageError("usage: orgm-hypr theme list [--registry PATH]")
		}
		for _, summary := range theme.Summaries(registry) {
			fmt.Fprintf(stdout, "%s\t%s\t%s\n", summary.ID, summary.Name, strings.Join(summary.Modes, ","))
		}
		return nil
	case "validate":
		if len(opts.positionals) != 0 || opts.dryRun || opts.mode != "" {
			return cli.UsageError("usage: orgm-hypr theme validate [--registry PATH]")
		}
		fmt.Fprintf(stdout, "valid: %d theme(s)\n", len(registry.Themes))
		return nil
	case "status":
		if len(opts.positionals) != 0 || opts.dryRun || opts.mode != "" {
			return cli.UsageError("usage: orgm-hypr theme status [--registry PATH]")
		}
		active, ok := theme.ActiveTheme(registry)
		if !ok {
			return cli.UsageError("active theme %q not found", registry.ActiveDefault)
		}
		wallpaperMode := active.Wallpaper.Mode
		if wallpaperMode == "" {
			wallpaperMode = "none"
		}
		fmt.Fprintf(stdout, "active=%s\nmode=%s\nwallpaper=%s\nlastApply=none\n", active.ID, active.DefaultMode, wallpaperMode)
		return nil
	case "export-neutral":
		if len(opts.positionals) != 0 || opts.mode != "" {
			return cli.UsageError("usage: orgm-hypr theme export-neutral [--dry-run] [--registry PATH]")
		}
		updated := theme.UpsertNeutralTheme(registry)
		if opts.dryRun {
			fmt.Fprintf(stdout, "dryRun=true\nwould update neutral theme in %s\n", opts.registryPath)
			return nil
		}
		if err := theme.SaveRegistryAtomic(opts.registryPath, updated); err != nil {
			return err
		}
		fmt.Fprintf(stdout, "updated neutral theme in %s\n", opts.registryPath)
		return nil
	case "preview", "apply":
		if len(opts.positionals) != 1 {
			return cli.UsageError("usage: orgm-hypr theme %s THEME [--mode dark|light|auto] [--dry-run] [--registry PATH]", args[0])
		}
		if args[0] == "preview" && opts.dryRun {
			return cli.UsageError("preview does not accept --dry-run")
		}
		selected, ok := findTheme(registry, opts.positionals[0])
		if !ok {
			return cli.UsageError("theme %q not found", opts.positionals[0])
		}
		plan, err := theme.BuildApplyPlan(selected, theme.PlanOptions{Mode: opts.mode, StateHome: env.StateHome, CacheHome: env.CacheHome, ConfigHome: env.ConfigHome})
		if err != nil {
			return cli.UsageError(err.Error())
		}
		dryRun := args[0] == "preview" || opts.dryRun
		printThemePlan(stdout, plan, dryRun)
		if args[0] == "apply" && !opts.dryRun {
			writer := theme.AtomicWriter{Marker: theme.GeneratedMarker}
			manifest := theme.LastApplyManifest{ThemeID: plan.ThemeID, Mode: plan.Mode}
			for _, write := range plan.Writes {
				result, err := writer.Write(write.Path, write.Content, write.Mode)
				if err != nil {
					return err
				}
				manifest.Writes = append(manifest.Writes, theme.LastApplyManifestWrite{Target: write.Target, Path: write.Path, BackupPath: result.BackupPath})
			}
			if err := theme.SaveLastApplyManifest(env.StateHome, manifest); err != nil {
				return err
			}
		}
		return nil
	default:
		return cli.UsageError("usage: orgm-hypr theme [list|validate|status|preview|apply|export-neutral]")
	}
}

type themeCommandEnv struct {
	RegistryPath string
	StateHome    string
	CacheHome    string
	ConfigHome   string
}

type themeFlagOptions struct {
	registryPath string
	mode         string
	dryRun       bool
	positionals  []string
}

func defaultThemeCommandEnv() themeCommandEnv {
	return themeCommandEnv{
		RegistryPath: defaultThemeRegistryPath(),
		StateHome:    defaultXDGPath("XDG_STATE_HOME", ".local/state"),
		CacheHome:    defaultXDGPath("XDG_CACHE_HOME", ".cache"),
		ConfigHome:   defaultXDGPath("XDG_CONFIG_HOME", ".config"),
	}
}

func defaultThemeRegistryPath() string {
	if configHome := os.Getenv("XDG_CONFIG_HOME"); configHome != "" {
		return filepath.Join(configHome, "orgm-hypr", "themes.json")
	}
	return filepath.Join(os.Getenv("HOME"), ".config", "orgm-hypr", "themes.json")
}

func defaultXDGPath(envName, homeRelative string) string {
	if value := os.Getenv(envName); value != "" {
		return value
	}
	return filepath.Join(os.Getenv("HOME"), homeRelative)
}

func parseThemeFlags(args []string, defaultRegistryPath string) (themeFlagOptions, error) {
	opts := themeFlagOptions{registryPath: defaultRegistryPath}
	for i := 0; i < len(args); i++ {
		arg := args[i]
		switch arg {
		case "--registry":
			if i+1 >= len(args) {
				return opts, fmt.Errorf("--registry requires a value")
			}
			i++
			opts.registryPath = args[i]
		case "--mode":
			if i+1 >= len(args) {
				return opts, fmt.Errorf("--mode requires a value")
			}
			i++
			opts.mode = args[i]
		case "--dry-run":
			opts.dryRun = true
		default:
			if strings.HasPrefix(arg, "--") {
				return opts, fmt.Errorf("unknown flag: %s", arg)
			}
			opts.positionals = append(opts.positionals, arg)
		}
	}
	return opts, nil
}

func findTheme(registry theme.Registry, id string) (theme.Theme, bool) {
	for _, item := range registry.Themes {
		if item.ID == id {
			return item, true
		}
	}
	return theme.Theme{}, false
}

func printThemePlan(stdout io.Writer, plan theme.ApplyPlan, dryRun bool) {
	fmt.Fprintf(stdout, "theme=%s\nmode=%s\ndryRun=%t\n", plan.ThemeID, plan.Mode, dryRun)
	fmt.Fprintln(stdout, "Writes:")
	if len(plan.Writes) == 0 {
		fmt.Fprintln(stdout, "  (none)")
	}
	for _, write := range plan.Writes {
		fmt.Fprintf(stdout, "  %s\n", write.Path)
	}
	fmt.Fprintln(stdout, "Reloads:")
	if len(plan.Reloads) == 0 {
		fmt.Fprintln(stdout, "  (none)")
	}
	for _, reload := range plan.Reloads {
		fmt.Fprintf(stdout, "  %s: %s\n", reload.Target, reload.Command)
	}
	fmt.Fprintln(stdout, "Warnings:")
	if len(plan.Warnings) == 0 {
		fmt.Fprintln(stdout, "  (none)")
	}
	for _, warning := range plan.Warnings {
		fmt.Fprintf(stdout, "  %s\n", warning)
	}
}

func runSessionWithIO(args []string, stdout, stderr io.Writer) error {
	if len(args) < 1 {
		return cli.UsageError("usage: orgm-hypr session [import-env|start-containers|start-discord]")
	}
	switch args[0] {
	case "import-env":
		flags := flag.NewFlagSet("orgm-hypr session import-env", flag.ContinueOnError)
		flags.SetOutput(stderr)
		printOnly := flags.Bool("print", false, "print commands without running them")
		if err := flags.Parse(args[1:]); err != nil {
			return cli.UsageError(err.Error())
		}
		if flags.NArg() != 0 {
			return cli.UsageError("unexpected argument: %s", flags.Arg(0))
		}
		commands := session.ImportEnvCommands()
		if *printOnly {
			for _, command := range commands {
				fmt.Fprintln(stdout, shellCommand(command.Name, command.Args))
			}
			return nil
		}
		for _, command := range commands {
			cmd := exec.Command(command.Name, command.Args...)
			cmd.Stdout = stdout
			cmd.Stderr = stderr
			if err := cmd.Run(); err != nil {
				return err
			}
		}
		return nil
	case "start-containers":
		flags := flag.NewFlagSet("orgm-hypr session start-containers", flag.ContinueOnError)
		flags.SetOutput(stderr)
		printOnly := flags.Bool("print", false, "print command without running it")
		engine := flags.String("engine", "auto", "auto, docker, or podman")
		if err := flags.Parse(args[1:]); err != nil {
			return cli.UsageError(err.Error())
		}
		names := flags.Args()
		if len(names) == 0 {
			names = []string{"arch", "windows"}
		}
		command, ok := session.ContainerStartCommand(names, func(name string) bool {
			if *engine == "auto" {
				return commandExists(name)
			}
			return name == *engine
		})
		if !ok {
			return fmt.Errorf("no supported container engine found")
		}
		if *printOnly {
			fmt.Fprintln(stdout, shellCommand(command.Name, command.Args))
			return nil
		}
		return runCommand(command.Name, command.Args, stdout, stderr, false)
	case "lock":
		flags := flag.NewFlagSet("orgm-hypr session lock", flag.ContinueOnError)
		flags.SetOutput(stderr)
		printOnly := flags.Bool("print", false, "print command without locking")
		force := flags.Bool("force", false, "run live lock command")
		if err := flags.Parse(args[1:]); err != nil {
			return cli.UsageError(err.Error())
		}
		if flags.NArg() != 0 {
			return cli.UsageError("unexpected argument: %s", flags.Arg(0))
		}
		command := windows.Command{Name: "hyprlock", Args: []string{"--immediate-render", "--no-fade-in"}}
		if *printOnly {
			fmt.Fprintln(stdout, shellCommand(command.Name, command.Args))
			return nil
		}
		if !*force {
			return cli.UsageError("session lock live mode requires --force or --print")
		}
		if exec.Command("pgrep", "-x", "hyprlock").Run() == nil {
			return nil
		}
		if commandExists("hyprlock") {
			return runCommand(command.Name, command.Args, stdout, stderr, false)
		}
		return runCommand("loginctl", []string{"lock-session"}, stdout, stderr, false)
	case "start-discord":
		flags := flag.NewFlagSet("orgm-hypr session start-discord", flag.ContinueOnError)
		flags.SetOutput(stderr)
		printOnly := flags.Bool("print", false, "print command without running it")
		flatpakOnly := flags.Bool("flatpak", false, "force flatpak plan for tests")
		if err := flags.Parse(args[1:]); err != nil {
			return cli.UsageError(err.Error())
		}
		if flags.NArg() != 0 {
			return cli.UsageError("unexpected argument: %s", flags.Arg(0))
		}
		command, ok := session.DiscordCommand(func(name string) bool {
			if *flatpakOnly {
				return name == "flatpak"
			}
			return commandExists(name)
		}, func(appID string) bool {
			if *flatpakOnly {
				return appID == "com.discordapp.Discord"
			}
			return flatpakAppExists(appID)
		})
		if !ok {
			return nil
		}
		if *printOnly {
			fmt.Fprintln(stdout, shellCommand(command.Name, command.Args))
			return nil
		}
		return runCommand(command.Name, command.Args, stdout, stderr, true)
	default:
		return cli.UsageError("usage: orgm-hypr session [import-env|start-containers|start-discord]")
	}
}

func runWaybarWithIO(args []string, stdout, stderr io.Writer) error {
	if len(args) < 1 {
		return cli.UsageError("usage: orgm-hypr waybar [date|swap-usage|watch|watch-plan|workspace]")
	}
	switch args[0] {
	case "date":
		flags := flag.NewFlagSet("orgm-hypr waybar date", flag.ContinueOnError)
		flags.SetOutput(stderr)
		format := flags.String("format", "date-es", "date-es, day-month-es, or time-ampm")
		timeValue := flags.String("time", "", "RFC3339 time override for tests")
		if err := flags.Parse(args[1:]); err != nil {
			return cli.UsageError(err.Error())
		}
		if flags.NArg() != 0 {
			return cli.UsageError("unexpected argument: %s", flags.Arg(0))
		}
		now := time.Now()
		if *timeValue != "" {
			parsed, err := time.Parse(time.RFC3339, *timeValue)
			if err != nil {
				return cli.UsageError("invalid --time: %v", err)
			}
			now = parsed
		}
		text, err := waybar.FormatDate(now, *format)
		if err != nil {
			return cli.UsageError(err.Error())
		}
		fmt.Fprintln(stdout, text)
		return nil
	case "swap-usage":
		flags := flag.NewFlagSet("orgm-hypr waybar swap-usage", flag.ContinueOnError)
		flags.SetOutput(stderr)
		meminfo := flags.String("meminfo", "/proc/meminfo", "meminfo path")
		if err := flags.Parse(args[1:]); err != nil {
			return cli.UsageError(err.Error())
		}
		if flags.NArg() != 0 {
			return cli.UsageError("unexpected argument: %s", flags.Arg(0))
		}
		file, err := os.Open(*meminfo)
		if err != nil {
			return err
		}
		defer file.Close()
		text, err := waybar.SwapUsageFromMeminfo(file)
		if err != nil {
			return err
		}
		fmt.Fprintln(stdout, text)
		return nil
	case "watch-plan":
		if len(args) != 2 {
			return cli.UsageError("usage: orgm-hypr waybar watch-plan CONFIG_DIR")
		}
		plan := waybar.WatchPlan(args[1], defaultXDGPath("XDG_STATE_HOME", ".local/state"))
		fmt.Fprintf(stdout, "log=%s\nwaybar=%s\n", plan.LogPath, shellCommand("waybar", plan.WaybarArgs))
		return nil
	case "watch":
		return runWaybarWatchWithIO(args[1:], stdout, stderr)
	case "workspace":
		return runWaybarWorkspaceWithIO(args[1:], stdout, stderr)
	default:
		return cli.UsageError("usage: orgm-hypr waybar [date|swap-usage|watch|watch-plan|workspace]")
	}
}

func runWaybarWatchWithIO(args []string, stdout, stderr io.Writer) error {
	flags := flag.NewFlagSet("orgm-hypr waybar watch", flag.ContinueOnError)
	flags.SetOutput(stderr)
	printOnly := flags.Bool("print", false, "print watcher plan without running")
	if err := flags.Parse(args); err != nil {
		return cli.UsageError(err.Error())
	}
	if flags.NArg() > 1 {
		return cli.UsageError("usage: orgm-hypr waybar watch [CONFIG_DIR] [--print]")
	}
	configDir := defaultXDGPath("WAYBAR_CONFIG_DIR", ".config/waybar")
	if flags.NArg() == 1 {
		configDir = flags.Arg(0)
	}
	plan := waybar.WatchPlan(configDir, defaultXDGPath("XDG_STATE_HOME", ".local/state"))
	if *printOnly {
		fmt.Fprintf(stdout, "log=%s\nwaybar=%s\n", plan.LogPath, shellCommand("waybar", plan.WaybarArgs))
		return nil
	}
	if err := os.MkdirAll(filepath.Dir(plan.LogPath), 0o700); err != nil {
		return err
	}
	for {
		_ = exec.Command("pkill", "-KILL", "-f", `(^|/)waybar($| )|[.]waybar-wrapped`).Run()
		logFile, err := os.OpenFile(plan.LogPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o600)
		if err != nil {
			return err
		}
		cmd := exec.Command("waybar", plan.WaybarArgs...)
		cmd.Stdout = logFile
		cmd.Stderr = logFile
		_ = cmd.Run()
		_ = logFile.Close()
		time.Sleep(2 * time.Second)
	}
}

func runWaybarWorkspaceWithIO(args []string, stdout, stderr io.Writer) error {
	if len(args) < 2 {
		return cli.UsageError("usage: orgm-hypr waybar workspace [status|click] WORKSPACE_ID")
	}
	workspaceID, err := strconv.Atoi(args[1])
	if err != nil || workspaceID <= 0 {
		return cli.UsageError("workspace ID must be a positive integer")
	}
	switch args[0] {
	case "status":
		flags := flag.NewFlagSet("orgm-hypr waybar workspace status", flag.ContinueOnError)
		flags.SetOutput(stderr)
		active := flags.Int("active", 0, "active workspace id")
		windowsCount := flags.Int("windows", -1, "window count")
		monitorsPath := flags.String("monitors", "", "hyprctl monitors JSON file for tests")
		workspacesPath := flags.String("workspaces", "", "hyprctl workspaces JSON file for tests")
		if err := flags.Parse(args[2:]); err != nil {
			return cli.UsageError(err.Error())
		}
		if flags.NArg() != 0 {
			return cli.UsageError("unexpected argument: %s", flags.Arg(0))
		}
		activeID := *active
		if activeID == 0 {
			activeID, err = activeWorkspaceID(*monitorsPath)
			if err != nil {
				return err
			}
		}
		count := *windowsCount
		if count < 0 {
			count, err = workspaceWindowCount(workspaceID, *workspacesPath)
			if err != nil {
				return err
			}
		}
		text, err := waybar.WorkspaceStatusJSON(workspaceID, activeID, count)
		if err != nil {
			return err
		}
		fmt.Fprint(stdout, text)
		return nil
	case "click":
		flags := flag.NewFlagSet("orgm-hypr waybar workspace click", flag.ContinueOnError)
		flags.SetOutput(stderr)
		printOnly := flags.Bool("print", false, "print command without running it")
		if err := flags.Parse(args[2:]); err != nil {
			return cli.UsageError(err.Error())
		}
		if flags.NArg() != 0 {
			return cli.UsageError("unexpected argument: %s", flags.Arg(0))
		}
		command := []string{"dispatch", fmt.Sprintf("hl.dsp.focus({ workspace = %d })", workspaceID)}
		if *printOnly {
			fmt.Fprintln(stdout, shellCommand("hyprctl", command))
			return nil
		}
		cmd := exec.Command("hyprctl", command...)
		cmd.Stdout = stdout
		cmd.Stderr = stderr
		return cmd.Run()
	default:
		return cli.UsageError("usage: orgm-hypr waybar workspace [status|click] WORKSPACE_ID")
	}
}

func runDockWithIO(args []string, stdout, stderr io.Writer) error {
	if len(args) < 1 {
		return cli.UsageError("usage: orgm-hypr dock start [--reload] [--print-args]")
	}
	if args[0] != "start" {
		return cli.UsageError("usage: orgm-hypr dock start [--reload] [--print-args]")
	}
	flags := flag.NewFlagSet("orgm-hypr dock start", flag.ContinueOnError)
	flags.SetOutput(stderr)
	printArgs := flags.Bool("print-args", false, "print compatibility command without starting")
	reload := flags.Bool("reload", false, "restart existing dock before start")
	flagArgs, reloadAlias := normalizeDockArgs(args[1:])
	if err := flags.Parse(flagArgs); err != nil {
		return cli.UsageError(err.Error())
	}
	if flags.NArg() > 1 {
		return cli.UsageError("unexpected argument: %s", flags.Arg(1))
	}
	if flags.NArg() == 1 {
		return cli.UsageError("unexpected argument: %s", flags.Arg(0))
	}
	reloadValue := *reload || reloadAlias
	env := dock.Env{
		Home:             os.Getenv("HOME"),
		IconSize:         os.Getenv("HYPR_NWG_DOCK_ICON_SIZE"),
		MarginRight:      os.Getenv("HYPR_NWG_DOCK_MARGIN_RIGHT"),
		MarginTop:        os.Getenv("HYPR_NWG_DOCK_MARGIN_TOP"),
		MarginBottom:     os.Getenv("HYPR_NWG_DOCK_MARGIN_BOTTOM"),
		LauncherPosition: os.Getenv("HYPR_NWG_DOCK_LAUNCHER_POSITION"),
		LauncherIcon:     os.Getenv("HYPR_NWG_DOCK_LAUNCHER_ICON"),
		LauncherCommand:  os.Getenv("HYPR_NWG_DOCK_LAUNCHER_COMMAND"),
	}
	argsForDock := dock.StartArgs(env)
	if *printArgs {
		fmt.Fprintln(stdout, shellCommand("nwg-dock-hyprland", argsForDock))
		return nil
	}
	if _, err := exec.LookPath("nwg-dock-hyprland"); err != nil {
		notify := exec.Command("notify-send", "Hyprland dock", "nwg-dock-hyprland is not installed yet")
		_ = notify.Run()
		return fmt.Errorf("nwg-dock-hyprland is not installed yet")
	}
	if reloadValue {
		_ = exec.Command("pkill", "-f", "^nwg-dock-hyprland( |$)").Run()
		time.Sleep(200 * time.Millisecond)
	}
	cmd := exec.Command("nwg-dock-hyprland", argsForDock...)
	cmd.Stdout = stdout
	cmd.Stderr = stderr
	return cmd.Start()
}

func activeWorkspaceID(path string) (int, error) {
	data, err := readHyprJSON(path, "monitors")
	if err != nil {
		return 0, err
	}
	var monitors []struct {
		Focused         bool `json:"focused"`
		ActiveWorkspace struct {
			ID int `json:"id"`
		} `json:"activeWorkspace"`
	}
	if err := json.Unmarshal(data, &monitors); err != nil {
		return 0, err
	}
	for _, monitor := range monitors {
		if monitor.Focused {
			return monitor.ActiveWorkspace.ID, nil
		}
	}
	if len(monitors) > 0 {
		return monitors[0].ActiveWorkspace.ID, nil
	}
	return 0, nil
}

func workspaceWindowCount(workspaceID int, path string) (int, error) {
	data, err := readHyprJSON(path, "workspaces")
	if err != nil {
		return 0, err
	}
	var workspaces []struct {
		ID      int `json:"id"`
		Windows int `json:"windows"`
	}
	if err := json.Unmarshal(data, &workspaces); err != nil {
		return 0, err
	}
	for _, workspace := range workspaces {
		if workspace.ID == workspaceID {
			return workspace.Windows, nil
		}
	}
	return 0, nil
}

func readHyprJSON(path, what string) ([]byte, error) {
	if path != "" {
		return os.ReadFile(path)
	}
	return exec.Command("hyprctl", "-j", what).Output()
}

func normalizeDockArgs(args []string) ([]string, bool) {
	out := make([]string, 0, len(args))
	reloadAlias := false
	for _, arg := range args {
		if arg == "reload" || arg == "restart" {
			reloadAlias = true
			continue
		}
		out = append(out, arg)
	}
	return out, reloadAlias
}

func runWindowsWithIO(args []string, stdout, stderr io.Writer) error {
	if len(args) < 1 {
		return cli.UsageError("usage: orgm-hypr windows [list|focus|switch|kill-menu]")
	}
	switch args[0] {
	case "list":
		flags := flag.NewFlagSet("orgm-hypr windows list", flag.ContinueOnError)
		flags.SetOutput(stderr)
		clientsPath := flags.String("clients", "", "hyprctl clients JSON file for tests")
		if err := flags.Parse(args[1:]); err != nil {
			return cli.UsageError(err.Error())
		}
		if flags.NArg() != 0 {
			return cli.UsageError("unexpected argument: %s", flags.Arg(0))
		}
		data, err := readHyprClientsJSON(*clientsPath)
		if err != nil {
			return err
		}
		rows, err := windows.ClientRowsFromJSON(data)
		if err != nil {
			return err
		}
		for _, row := range rows {
			fmt.Fprintf(stdout, "%s\t%s\n", row.Address, row.Label)
		}
		return nil
	case "focus":
		address, printOnly, err := parseFocusArgs(args[1:])
		if err != nil {
			return cli.UsageError(err.Error())
		}
		command, ok := windows.FocusCommand(address)
		if !ok {
			return cli.UsageError("usage: orgm-hypr windows focus ADDRESS [--print]")
		}
		return runOrPrintCommand(command, printOnly, stdout, stderr)
	case "switch":
		return runWindowsSwitchWithIO(args[1:], stdout, stderr)
	case "kill-menu":
		return runWindowsKillMenuWithIO(args[1:], stdout, stderr)
	default:
		return cli.UsageError("usage: orgm-hypr windows [list|focus|switch|kill-menu]")
	}
}

func runWindowsSwitchWithIO(args []string, stdout, stderr io.Writer) error {
	flags := flag.NewFlagSet("orgm-hypr windows switch", flag.ContinueOnError)
	flags.SetOutput(stderr)
	clientsPath := flags.String("clients", "", "hyprctl clients JSON file for tests")
	selectValue := flags.String("select", "", "selected label for tests")
	launcher := flags.String("launcher", "fuzzel", "fuzzel, walker, or rofi")
	printOnly := flags.Bool("print", false, "print focus command without running it")
	if err := flags.Parse(args); err != nil {
		return cli.UsageError(err.Error())
	}
	if flags.NArg() != 0 {
		return cli.UsageError("unexpected argument: %s", flags.Arg(0))
	}
	data, err := readHyprClientsJSON(*clientsPath)
	if err != nil {
		return err
	}
	rows, err := windows.ClientRowsFromJSON(data)
	if err != nil {
		return err
	}
	labels := make([]string, 0, len(rows))
	byLabel := map[string]string{}
	for _, row := range rows {
		labels = append(labels, row.Label)
		byLabel[row.Label] = row.Address
	}
	selection := *selectValue
	if selection == "" {
		if len(labels) == 0 {
			return nil
		}
		selection, err = dmenuPick(*launcher, "Window> ", labels, stderr)
		if err != nil || selection == "" {
			return err
		}
	}
	command, ok := windows.FocusCommand(byLabel[selection])
	if !ok {
		return fmt.Errorf("selected window not found")
	}
	return runOrPrintCommand(command, *printOnly, stdout, stderr)
}

func runWindowsKillMenuWithIO(args []string, stdout, stderr io.Writer) error {
	flags := flag.NewFlagSet("orgm-hypr windows kill-menu", flag.ContinueOnError)
	flags.SetOutput(stderr)
	clientsPath := flags.String("clients", "", "hyprctl clients JSON file for tests")
	selectValue := flags.String("select", "", "selected label for tests")
	pidRSS := flags.String("pid-rss", "", "test RSS map, e.g. 101=20480")
	minRSS := flags.Int("min-rss-kb", 10240, "minimum RSS in KB")
	printOnly := flags.Bool("print", false, "print kill command without running it")
	if err := flags.Parse(args); err != nil {
		return cli.UsageError(err.Error())
	}
	if flags.NArg() != 0 {
		return cli.UsageError("unexpected argument: %s", flags.Arg(0))
	}
	data, err := readHyprClientsJSON(*clientsPath)
	if err != nil {
		return err
	}
	rssMap := parsePIDRSS(*pidRSS)
	candidates, err := windows.KillCandidatesFromJSON(data, *minRSS, func(pid int) (int, bool) {
		if rss, ok := rssMap[pid]; ok {
			return rss, true
		}
		return procRSSOwned(pid)
	})
	if err != nil {
		return err
	}
	if len(candidates) == 0 {
		fmt.Fprintln(stderr, "No Hyprland window process over 10 MB.")
		return nil
	}
	labels := make([]string, 0, len(candidates))
	byLabel := map[string]int{}
	for _, candidate := range candidates {
		labels = append(labels, candidate.Label)
		byLabel[candidate.Label] = candidate.PID
	}
	selection := *selectValue
	if selection == "" {
		selection, err = dmenuPick("fuzzel", "Kill window> ", labels, stderr)
		if err != nil || selection == "" {
			return err
		}
	}
	pid := byLabel[selection]
	if pid <= 0 {
		return fmt.Errorf("selected process not found")
	}
	if *printOnly {
		fmt.Fprintf(stdout, "kill -TERM %d\n", pid)
		return nil
	}
	return exec.Command("kill", "-TERM", strconv.Itoa(pid)).Run()
}

func runZenWithIO(args []string, stdout, stderr io.Writer) error {
	if len(args) < 1 {
		return cli.UsageError("usage: orgm-hypr zen [focus|open-new-window]")
	}
	switch args[0] {
	case "focus":
		flags := flag.NewFlagSet("orgm-hypr zen focus", flag.ContinueOnError)
		flags.SetOutput(stderr)
		clientsPath := flags.String("clients", "", "hyprctl clients JSON file for tests")
		printOnly := flags.Bool("print", false, "print command without running it")
		if err := flags.Parse(args[1:]); err != nil {
			return cli.UsageError(err.Error())
		}
		if flags.NArg() != 0 {
			return cli.UsageError("unexpected argument: %s", flags.Arg(0))
		}
		data, err := readHyprClientsJSON(*clientsPath)
		if err != nil {
			return err
		}
		address, ok, err := zen.FocusAddressFromClients(data)
		if err != nil {
			return err
		}
		if !ok {
			return nil
		}
		command, _ := windows.FocusCommand(address)
		if *printOnly {
			fmt.Fprintln(stdout, shellCommand(command.Name, command.Args))
			return nil
		}
		cmd := exec.Command(command.Name, command.Args...)
		cmd.Stdout = stdout
		cmd.Stderr = stderr
		return cmd.Run()
	case "open-new-window":
		return runZenOpenNewWindowWithIO(args[1:], stdout, stderr)
	default:
		return cli.UsageError("usage: orgm-hypr zen [focus|open-new-window]")
	}
}

func runZenOpenNewWindowWithIO(args []string, stdout, stderr io.Writer) error {
	flags := flag.NewFlagSet("orgm-hypr zen open-new-window", flag.ContinueOnError)
	flags.SetOutput(stderr)
	printOnly := flags.Bool("print", false, "print command without running it")
	alreadyRunning := flags.Bool("already-running", false, "force already-running state for tests")
	flatpakFound := flags.Bool("flatpak", false, "force flatpak binary presence for tests")
	flatpakZen := flags.Bool("flatpak-zen", false, "force Zen flatpak app presence for tests")
	zenBrowser := flags.Bool("zen-browser", false, "force zen-browser presence for tests")
	zenBinary := flags.Bool("zen", false, "force zen binary presence for tests")
	if err := flags.Parse(args); err != nil {
		return cli.UsageError(err.Error())
	}
	if flags.NArg() != 0 {
		return cli.UsageError("unexpected argument: %s", flags.Arg(0))
	}
	state := zen.InstallState{Flatpak: *flatpakFound, FlatpakZen: *flatpakZen, ZenBrowser: *zenBrowser, Zen: *zenBinary}
	if !*printOnly {
		state = zen.InstallState{Flatpak: commandExists("flatpak"), FlatpakZen: flatpakAppExists("app.zen_browser.zen"), ZenBrowser: commandExists("zen-browser"), Zen: commandExists("zen")}
		*alreadyRunning = zenAlreadyRunning()
	}
	command, ok := zen.OpenCommand(state, *alreadyRunning)
	if !ok {
		if *printOnly {
			return cli.UsageError("Zen Browser is not installed")
		}
		_ = exec.Command("notify-send", "Zen Browser", "Zen Browser is not installed").Run()
		return fmt.Errorf("Zen Browser is not installed")
	}
	if *printOnly {
		fmt.Fprintln(stdout, shellCommand(command.Name, command.Args))
		return nil
	}
	cmd := exec.Command(command.Name, command.Args...)
	cmd.Stdout = stdout
	cmd.Stderr = stderr
	if err := cmd.Start(); err != nil {
		return err
	}
	return runZenWithIO([]string{"focus"}, stdout, stderr)
}

func flatpakAppExists(appID string) bool {
	return exec.Command("flatpak", "info", appID).Run() == nil
}

func zenAlreadyRunning() bool {
	data, err := readHyprClientsJSON("")
	if err != nil {
		return false
	}
	_, ok, err := zen.FocusAddressFromClients(data)
	return err == nil && ok
}

func runOSDWithIO(args []string, stdout, stderr io.Writer) error {
	if len(args) < 2 {
		return cli.UsageError("usage: orgm-hypr osd [volume|mic|brightness] ACTION")
	}
	flags := flag.NewFlagSet("orgm-hypr osd", flag.ContinueOnError)
	flags.SetOutput(stderr)
	printOnly := flags.Bool("print", false, "print command and notify payload without running")
	volume := flags.Int("volume", 0, "current volume/brightness value for tests")
	muted := flags.Bool("muted", false, "current mute state for tests")
	if err := flags.Parse(args[2:]); err != nil {
		return cli.UsageError(err.Error())
	}
	if flags.NArg() != 0 {
		return cli.UsageError("unexpected argument: %s", flags.Arg(0))
	}
	var plan osd.Plan
	var err error
	switch args[0] {
	case "volume":
		plan, err = osd.PlanVolume(args[1], osd.DeviceState{Volume: *volume, Muted: *muted})
	case "mic":
		plan, err = osd.PlanMic(args[1], osd.DeviceState{Volume: *volume, Muted: *muted})
	case "brightness":
		plan, err = osd.PlanBrightness(args[1], *volume)
	default:
		return cli.UsageError("usage: orgm-hypr osd [volume|mic|brightness] ACTION")
	}
	if err != nil {
		return cli.UsageError(err.Error())
	}
	if *printOnly {
		fmt.Fprintln(stdout, shellCommand(plan.Command.Name, plan.Command.Args))
		fmt.Fprintln(stdout, shellCommand("notify-send", notifyArgs(plan.Notify)))
		return nil
	}
	if err := runSilent(plan.Command.Name, plan.Command.Args, stderr); err != nil {
		return err
	}
	state := osd.DeviceState{Volume: *volume, Muted: *muted}
	if args[0] == "volume" || args[0] == "mic" {
		state = queryPamixerState(args[0] == "mic")
	}
	switch args[0] {
	case "volume":
		plan, err = osd.PlanVolume(args[1], state)
	case "mic":
		plan, err = osd.PlanMic(args[1], state)
	case "brightness":
		plan, err = osd.PlanBrightness(args[1], queryBrightnessPercent())
	}
	if err != nil {
		return cli.UsageError(err.Error())
	}
	if commandExists("notify-send") {
		_ = runSilent("notify-send", notifyArgs(plan.Notify), stderr)
	}
	return nil
}

func runMenuWithIO(args []string, stdout, stderr io.Writer) error {
	if len(args) < 1 {
		return cli.UsageError("usage: orgm-hypr menu [main|system|tools|performance|wifi|bluetooth|keyboard|power|keybindings]")
	}
	if args[0] == "keybindings" {
		return runMenuKeybindingsWithIO(args[1:], stdout, stderr)
	}
	flags := flag.NewFlagSet("orgm-hypr menu", flag.ContinueOnError)
	flags.SetOutput(stderr)
	printOnly := flags.Bool("print", false, "print menu or selected command")
	selectValue := flags.String("select", "", "selected label for tests/non-interactive use")
	confirm := flags.String("confirm", "", "confirm destructive action")
	if err := flags.Parse(args[1:]); err != nil {
		return cli.UsageError(err.Error())
	}
	if flags.NArg() != 0 {
		return cli.UsageError("unexpected argument: %s", flags.Arg(0))
	}
	model, ok := menu.Model(args[0])
	if !ok {
		return cli.UsageError("usage: orgm-hypr menu [main|system|tools|performance|wifi|bluetooth|keyboard|power|keybindings]")
	}
	selection := *selectValue
	if selection == "" {
		if *printOnly {
			for _, label := range menu.Labels(model.Items) {
				fmt.Fprintln(stdout, label)
			}
			return nil
		}
		picked, err := rofiPick(model.Prompt, menu.Labels(model.Items), stderr)
		if err != nil || picked == "" {
			return nil
		}
		selection = picked
	}
	plan, ok := menu.PlanSelection(args[0], selection)
	if !ok {
		return nil
	}
	if plan.Destructive && *confirm != plan.Confirmation && !*printOnly {
		return cli.UsageError("destructive action requires --confirm %s or --print", plan.Confirmation)
	}
	if *printOnly {
		fmt.Fprintln(stdout, shellCommand(plan.Command.Name, plan.Command.Args))
		return nil
	}
	return runCommand(plan.Command.Name, plan.Command.Args, stdout, stderr, true)
}

func runMenuKeybindingsWithIO(args []string, stdout, stderr io.Writer) error {
	flags := flag.NewFlagSet("orgm-hypr menu keybindings", flag.ContinueOnError)
	flags.SetOutput(stderr)
	category := flags.String("category", "all", "keybinding category")
	if err := flags.Parse(args); err != nil {
		return cli.UsageError(err.Error())
	}
	if flags.NArg() != 0 {
		return cli.UsageError("unexpected argument: %s", flags.Arg(0))
	}
	for _, entry := range menu.KeybindingEntries(*category) {
		fmt.Fprintf(stdout, "%s\t%s\t%s\n", entry.Key, entry.Description, entry.Command)
	}
	return nil
}

func runWebappWithIO(args []string, stdout, stderr io.Writer) error {
	if len(args) < 1 {
		return cli.UsageError("usage: orgm-hypr webapp [list|create|remove]")
	}
	flags := flag.NewFlagSet("orgm-hypr webapp", flag.ContinueOnError)
	flags.SetOutput(stderr)
	dataHome := flags.String("xdg-data-home", defaultXDGPath("XDG_DATA_HOME", ".local/share"), "XDG data home")
	switch args[0] {
	case "list":
		format := flags.String("format", "tsv", "tsv or json")
		if err := flags.Parse(args[1:]); err != nil {
			return cli.UsageError(err.Error())
		}
		if flags.NArg() != 0 {
			return cli.UsageError("unexpected argument: %s", flags.Arg(0))
		}
		apps, err := webapp.List(*dataHome)
		if err != nil {
			return err
		}
		if *format == "json" {
			data, err := json.Marshal(apps)
			if err != nil {
				return err
			}
			fmt.Fprintln(stdout, string(data))
			return nil
		}
		for _, app := range apps {
			fmt.Fprintf(stdout, "%s\t%s\t%s\n", app.Name, app.URL, app.DesktopPath)
		}
		return nil
	case "create":
		dryRun := flags.Bool("dry-run", false, "print plan without writing")
		interactive := flags.Bool("interactive", false, "prompt for app details")
		cancel := flags.Bool("cancel", false, "test-only interactive cancellation")
		name := flags.String("name", "", "app name")
		url := flags.String("url", "", "app URL")
		browser := flags.String("browser", "chromium", "browser command")
		if err := flags.Parse(args[1:]); err != nil {
			return cli.UsageError(err.Error())
		}
		if flags.NArg() != 0 {
			return cli.UsageError("unexpected argument: %s", flags.Arg(0))
		}
		if *interactive {
			if *cancel {
				fmt.Fprintln(stdout, "cancelled")
				return nil
			}
			if *name == "" {
				picked, err := rofiText("App name", "", stderr)
				if err != nil || strings.TrimSpace(picked) == "" {
					return err
				}
				*name = strings.TrimSpace(picked)
			}
			if *url == "" {
				picked, err := rofiText("URL", "https://", stderr)
				if err != nil || strings.TrimSpace(picked) == "" {
					return err
				}
				*url = strings.TrimSpace(picked)
			}
			if *browser == "chromium" {
				if picked, err := rofiPick("Browser", browserCandidates(), stderr); err == nil && strings.TrimSpace(picked) != "" {
					*browser = strings.TrimSpace(picked)
				}
			}
		}
		plan, err := webapp.CreatePlan(webapp.CreateOptions{DataHome: *dataHome, Name: *name, URL: *url, Browser: *browser})
		if err != nil {
			return cli.UsageError(err.Error())
		}
		printWebappCreatePlan(stdout, plan)
		if *dryRun {
			return nil
		}
		return writeWebappCreatePlan(plan)
	case "remove":
		dryRun := flags.Bool("dry-run", false, "print plan without deleting")
		interactive := flags.Bool("interactive", false, "prompt for app removal")
		cancel := flags.Bool("cancel", false, "test-only interactive cancellation")
		desktop := flags.String("desktop", "", "desktop file path")
		profile := flags.Bool("profile", false, "remove profile data")
		confirm := flags.String("confirm", "", "confirmation token")
		if err := flags.Parse(args[1:]); err != nil {
			return cli.UsageError(err.Error())
		}
		if flags.NArg() != 0 {
			return cli.UsageError("unexpected argument: %s", flags.Arg(0))
		}
		if *interactive {
			if *cancel {
				fmt.Fprintln(stdout, "cancelled")
				return nil
			}
			apps, err := webapp.List(*dataHome)
			if err != nil {
				return err
			}
			if len(apps) == 0 {
				return nil
			}
			labels := []string{}
			byLabel := map[string]webapp.App{}
			for _, app := range apps {
				label := app.Name + " — " + app.URL
				labels = append(labels, label)
				byLabel[label] = app
			}
			picked, err := rofiPick("Remove web app", labels, stderr)
			if err != nil || picked == "" {
				return err
			}
			app := byLabel[picked]
			*desktop = app.DesktopPath
			choice, err := rofiPick("Remove "+app.Name+"?", []string{"Remove launcher only", "Remove launcher and profile data", "Cancel"}, stderr)
			if err != nil || choice == "" || choice == "Cancel" {
				return err
			}
			if choice == "Remove launcher and profile data" {
				*profile = true
				*confirm = "delete-profile"
			}
		}
		plan, err := webapp.RemovePlan(webapp.RemoveOptions{DataHome: *dataHome, DesktopPath: *desktop, RemoveProfile: *profile, Confirm: *confirm})
		if err != nil {
			return cli.UsageError(err.Error())
		}
		for _, path := range plan.RemovePaths {
			fmt.Fprintf(stdout, "remove=%s\n", path)
		}
		if *dryRun {
			return nil
		}
		if *profile && *confirm != "delete-profile" {
			return cli.UsageError("profile removal requires --confirm delete-profile")
		}
		for _, path := range plan.RemovePaths {
			if err := os.RemoveAll(path); err != nil {
				return err
			}
		}
		return nil
	default:
		return cli.UsageError("usage: orgm-hypr webapp [list|create|remove]")
	}
}

func runLauncherWithIO(args []string, stdout, stderr io.Writer) error {
	if len(args) < 1 || args[0] != "apps" {
		return cli.UsageError("usage: orgm-hypr launcher apps [--print]")
	}
	flags := flag.NewFlagSet("orgm-hypr launcher apps", flag.ContinueOnError)
	flags.SetOutput(stderr)
	printOnly := flags.Bool("print", false, "print fuzzel command without running")
	height := flags.Float64("height", 1080, "monitor height for tests")
	scaleIn := flags.Float64("scale", 1, "monitor scale for tests")
	if err := flags.Parse(args[1:]); err != nil {
		return cli.UsageError(err.Error())
	}
	if flags.NArg() != 0 {
		return cli.UsageError("unexpected argument: %s", flags.Arg(0))
	}
	scale := (*height / *scaleIn) / 1080
	if scale < 1 {
		scale = 1
	}
	if scale > 1.35 {
		scale = 1.35
	}
	fenv := loadFuzzelEnv()
	scale = fuzzelFloat(fenv, "HYPR_FUZZEL_SCALE", scale)
	fargs := []string{fmt.Sprintf("--font=JetBrainsMono Nerd Font:size=%d", fuzzelInt(fenv, "HYPR_FUZZEL_FONT_SIZE", int(12*scale))), fmt.Sprintf("--width=%d", fuzzelInt(fenv, "HYPR_FUZZEL_WIDTH", int(34*scale))), fmt.Sprintf("--lines=%d", fuzzelInt(fenv, "HYPR_FUZZEL_LINES", int(10*scale))), fmt.Sprintf("--line-height=%d", fuzzelInt(fenv, "HYPR_FUZZEL_LINE_HEIGHT", int(22*scale)))}
	if *printOnly {
		fmt.Fprintln(stdout, shellCommand("fuzzel", fargs))
		return nil
	}
	return runCommand("fuzzel", fargs, stdout, stderr, false)
}

func runNotifyWithIO(args []string, stdout, stderr io.Writer) error {
	if len(args) < 1 || args[0] != "focus-app" {
		return cli.UsageError("usage: orgm-hypr notify focus-app [--print] [--config PATH]")
	}
	flags := flag.NewFlagSet("orgm-hypr notify focus-app", flag.ContinueOnError)
	flags.SetOutput(stderr)
	printOnly := flags.Bool("print", false, "print focus plan")
	pid := flags.String("pid", os.Getenv("SWAYNC_HINT_PI_FOCUS_PID"), "pid hint")
	pattern := flags.String("match", "", "class/title match")
	configPath := flags.String("config", defaultNotifyFocusConfigPath(), "notify focus allowlist config")
	if err := flags.Parse(args[1:]); err != nil {
		return cli.UsageError(err.Error())
	}
	if flags.NArg() != 0 {
		return cli.UsageError("unexpected argument: %s", flags.Arg(0))
	}
	if *pid != "" {
		if *printOnly {
			fmt.Fprintf(stdout, "focus-pid=%s\n", *pid)
			return nil
		}
		return focusNotifyPID(*pid, stdout, stderr)
	}
	if *pattern == "" {
		*pattern = firstNonEmpty(os.Getenv("SWAYNC_DESKTOP_ENTRY"), os.Getenv("SWAYNC_APP_NAME"), os.Getenv("SWAYNC_SUMMARY"))
	}
	allowed, normalizedPattern, err := notifyFocusAllowed(*pattern, *configPath)
	if err != nil {
		return err
	}
	if *printOnly {
		if allowed {
			fmt.Fprintf(stdout, "focus-match=%s\n", normalizedPattern)
		} else {
			fmt.Fprintf(stdout, "focus-disabled=%s\n", normalizedPattern)
		}
		return nil
	}
	if !allowed {
		return nil
	}
	return focusNotifyMatch(normalizedPattern, stdout, stderr)
}

func runFileWithIO(args []string, stdout, stderr io.Writer) error {
	if len(args) < 1 {
		return cli.UsageError("usage: orgm-hypr file [open|open-dir|open-terminal]")
	}
	mode := args[0]
	flags := flag.NewFlagSet("orgm-hypr file", flag.ContinueOnError)
	flags.SetOutput(stderr)
	printOnly := flags.Bool("print", false, "print opener command")
	home := flags.String("home", os.Getenv("HOME"), "home directory")
	selectValue := flags.String("select", "", "selected relative path")
	launcher := flags.String("launcher", "fuzzel", "launcher")
	if err := flags.Parse(args[1:]); err != nil {
		return cli.UsageError(err.Error())
	}
	if flags.NArg() != 0 {
		return cli.UsageError("unexpected argument: %s", flags.Arg(0))
	}
	selection := *selectValue
	if selection == "" {
		rows, _ := recentFiles(*home)
		selection, _ = dmenuPick(*launcher, filePrompt(mode), rows, stderr)
		if selection == "" {
			return nil
		}
	}
	path := filepath.Join(*home, selection)
	cmd := windows.Command{Name: "xdg-open", Args: []string{path}}
	if mode == "open-dir" {
		cmd = windows.Command{Name: "nautilus", Args: []string{"--new-window", filepath.Dir(path)}}
	}
	if mode == "open-terminal" {
		cmd = windows.Command{Name: "kitty", Args: []string{"--directory", filepath.Dir(path)}}
	}
	if mode != "open" && mode != "open-dir" && mode != "open-terminal" {
		return cli.UsageError("usage: orgm-hypr file [open|open-dir|open-terminal]")
	}
	return runOrPrintCommand(cmd, *printOnly, stdout, stderr)
}

func runSSHWithIO(args []string, stdout, stderr io.Writer) error {
	if len(args) < 1 || args[0] != "host" {
		return cli.UsageError("usage: orgm-hypr ssh host")
	}
	flags := flag.NewFlagSet("orgm-hypr ssh host", flag.ContinueOnError)
	flags.SetOutput(stderr)
	printOnly := flags.Bool("print", false, "print ssh command")
	home := flags.String("home", os.Getenv("HOME"), "home directory")
	selectValue := flags.String("select", "", "selected host")
	launcher := flags.String("launcher", "fuzzel", "launcher")
	if err := flags.Parse(args[1:]); err != nil {
		return cli.UsageError(err.Error())
	}
	selection := *selectValue
	if selection == "" {
		hosts := sshHosts(*home)
		selection, _ = dmenuPick(*launcher, "SSH> ", hosts, stderr)
		if selection == "" {
			return nil
		}
	}
	return runOrPrintCommand(windows.Command{Name: "kitty", Args: []string{"-e", "ssh", selection}}, *printOnly, stdout, stderr)
}

func runTmuxWithIO(args []string, stdout, stderr io.Writer) error {
	if len(args) < 1 || args[0] != "arch" {
		return cli.UsageError("usage: orgm-hypr tmux arch")
	}
	flags := flag.NewFlagSet("orgm-hypr tmux arch", flag.ContinueOnError)
	flags.SetOutput(stderr)
	printOnly := flags.Bool("print", false, "print tmux command")
	selectValue := flags.String("select", "", "selected tmux ls row")
	launcher := flags.String("launcher", "fuzzel", "launcher")
	if err := flags.Parse(args[1:]); err != nil {
		return cli.UsageError(err.Error())
	}
	selection := *selectValue
	if selection == "" {
		data, _ := exec.Command("distrobox-enter", "arch", "--", "tmux", "ls").Output()
		lines := strings.Split(strings.TrimSpace(string(data)), "\n")
		selection, _ = dmenuPick(*launcher, "tmux> ", lines, stderr)
		if selection == "" {
			return nil
		}
	}
	sessionName, _, _ := strings.Cut(selection, ":")
	return runOrPrintCommand(windows.Command{Name: "kitty", Args: []string{"-e", "distrobox-enter", "arch", "--", "tmux", "attach", "-t", sessionName}}, *printOnly, stdout, stderr)
}

func runCalcWithIO(args []string, stdout, stderr io.Writer) error {
	if len(args) < 1 || args[0] != "fuzzel" {
		return cli.UsageError("usage: orgm-hypr calc fuzzel")
	}
	flags := flag.NewFlagSet("orgm-hypr calc fuzzel", flag.ContinueOnError)
	flags.SetOutput(stderr)
	printOnly := flags.Bool("print", false, "print calc command")
	expr := flags.String("expr", "", "expression")
	if err := flags.Parse(args[1:]); err != nil {
		return cli.UsageError(err.Error())
	}
	if *expr == "" {
		picked, _ := dmenuPick("fuzzel", "Calc> ", []string{}, stderr)
		*expr = picked
		if *expr == "" {
			return nil
		}
	}
	if *printOnly {
		fmt.Fprintf(stdout, "qalc -t %s\nwl-copy\nnotify-send Calc\n", *expr)
		return nil
	}
	data, err := exec.Command("qalc", "-t", *expr).Output()
	if err != nil {
		return err
	}
	result := strings.TrimSpace(string(data))
	return runExecutionPlan(smartrun.ExecutionPlan{Commands: []smartrun.Command{{Name: "wl-copy", Stdin: result}, {Name: "notify-send", Args: []string{"Calc", *expr + " = " + result}}}}, stdout, stderr)
}

func runPiWithIO(args []string, stdout, stderr io.Writer) error {
	if len(args) < 1 || args[0] != "prompt" {
		return cli.UsageError("usage: orgm-hypr pi prompt")
	}
	flags := flag.NewFlagSet("orgm-hypr pi prompt", flag.ContinueOnError)
	flags.SetOutput(stderr)
	printOnly := flags.Bool("print", false, "print pi command")
	input := flags.String("input", "", "prompt input")
	launcher := flags.String("launcher", "walker", "walker, rofi, or stdin")
	if err := flags.Parse(args[1:]); err != nil {
		return cli.UsageError(err.Error())
	}
	value := strings.TrimSpace(*input)
	if value == "" && !*printOnly {
		picked, _ := dmenuPick(*launcher, "Pedir instrucción a Pi", []string{}, stderr)
		value = strings.TrimSpace(picked)
	}
	if value == "" {
		return nil
	}
	cmd := windows.Command{Name: "kitty", Args: []string{"--class", "kitty", "--hold", "-e", "distrobox-enter", "arch", "--", "pi", value}}
	return runOrPrintCommand(cmd, *printOnly, stdout, stderr)
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if value != "" {
			return value
		}
	}
	return ""
}

func normalizeNotifyPattern(value string) string {
	value = strings.TrimSuffix(strings.ToLower(value), ".desktop")
	parts := strings.FieldsFunc(value, func(r rune) bool { return !(r >= 'a' && r <= 'z' || r >= '0' && r <= '9') })
	return strings.Join(parts, "[-_.]*")
}

func focusNotifyPID(pid string, stdout, stderr io.Writer) error {
	data, err := readHyprClientsJSON("")
	if err != nil {
		return err
	}
	var clients []struct {
		PID     int    `json:"pid"`
		Address string `json:"address"`
	}
	if err := json.Unmarshal(data, &clients); err != nil {
		return err
	}
	for _, client := range clients {
		if strconv.Itoa(client.PID) == pid {
			cmd, _ := windows.FocusCommand(client.Address)
			return runOrPrintCommand(cmd, false, stdout, stderr)
		}
	}
	return nil
}

func focusNotifyMatch(pattern string, stdout, stderr io.Writer) error {
	pattern = normalizeNotifyPattern(pattern)
	if pattern == "" {
		return nil
	}
	data, err := readHyprClientsJSON("")
	if err != nil {
		return err
	}
	rows, err := windows.ClientRowsFromJSON(data)
	if err != nil {
		return err
	}
	for _, row := range rows {
		if strings.Contains(normalizeNotifyPattern(row.Label), pattern) {
			cmd, _ := windows.FocusCommand(row.Address)
			return runOrPrintCommand(cmd, false, stdout, stderr)
		}
	}
	return nil
}

type notifyFocusConfig struct {
	Allow []notifyFocusRule `json:"allow"`
}

type notifyFocusRule struct {
	Match string `json:"match"`
}

func defaultNotifyFocusConfigPath() string {
	configHome := os.Getenv("XDG_CONFIG_HOME")
	if configHome == "" {
		configHome = filepath.Join(os.Getenv("HOME"), ".config")
	}
	return filepath.Join(configHome, "orgm-hypr", "notify-focus.json")
}

func defaultNotifyFocusRules() []notifyFocusRule {
	return []notifyFocusRule{{Match: "Pi Question"}, {Match: "pi-question"}, {Match: "Dota 2"}, {Match: "dota2"}, {Match: "steam_app_570"}}
}

func loadNotifyFocusRules(path string) ([]notifyFocusRule, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) && path == defaultNotifyFocusConfigPath() {
			return defaultNotifyFocusRules(), nil
		}
		return nil, err
	}
	var config notifyFocusConfig
	if err := json.Unmarshal(data, &config); err != nil {
		return nil, err
	}
	if len(config.Allow) == 0 {
		return nil, nil
	}
	return config.Allow, nil
}

func notifyFocusAllowed(pattern, configPath string) (bool, string, error) {
	normalizedPattern := normalizeNotifyPattern(pattern)
	if normalizedPattern == "" {
		return false, "", nil
	}
	rules, err := loadNotifyFocusRules(configPath)
	if err != nil {
		return false, normalizedPattern, err
	}
	for _, rule := range rules {
		normalizedRule := normalizeNotifyPattern(rule.Match)
		if normalizedRule != "" && strings.Contains(normalizedPattern, normalizedRule) {
			return true, normalizedPattern, nil
		}
	}
	return false, normalizedPattern, nil
}

func runObsidianWithIO(args []string, stdout, stderr io.Writer) error {
	if len(args) < 1 || args[0] != "open-or-focus" {
		return cli.UsageError("usage: orgm-hypr obsidian open-or-focus [--print] [--clients PATH]")
	}
	flags := flag.NewFlagSet("orgm-hypr obsidian open-or-focus", flag.ContinueOnError)
	flags.SetOutput(stderr)
	printOnly := flags.Bool("print", false, "print focus/open plan")
	clientsPath := flags.String("clients", "", "hyprctl clients JSON file for tests")
	if err := flags.Parse(args[1:]); err != nil {
		return cli.UsageError(err.Error())
	}
	if flags.NArg() != 0 {
		return cli.UsageError("unexpected argument: %s", flags.Arg(0))
	}
	command, err := obsidianOpenOrFocusCommand(*clientsPath)
	if err != nil {
		return err
	}
	return runOrPrintCommand(command, *printOnly, stdout, stderr)
}

func obsidianOpenOrFocusCommand(clientsPath string) (windows.Command, error) {
	data, err := readHyprClientsJSON(clientsPath)
	if err != nil {
		return windows.Command{}, err
	}
	var clients []struct {
		Address      string `json:"address"`
		Class        string `json:"class"`
		InitialClass string `json:"initialClass"`
		Title        string `json:"title"`
	}
	if err := json.Unmarshal(data, &clients); err != nil {
		return windows.Command{}, err
	}
	for _, client := range clients {
		label := normalizeNotifyPattern(strings.Join([]string{client.Class, client.InitialClass, client.Title}, " "))
		if strings.Contains(label, "obsidian") {
			cmd, _ := windows.FocusCommand(client.Address)
			return cmd, nil
		}
	}
	return windows.Command{Name: "obsidian"}, nil
}

func recentFiles(home string) ([]string, error) {
	out := []string{}
	err := filepath.WalkDir(home, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			return nil
		}
		if d.IsDir() {
			if path == home {
				return nil
			}
			name := d.Name()
			if strings.HasPrefix(name, ".") || isHeavyFileSearchDir(name) {
				return filepath.SkipDir
			}
			return nil
		}
		rel, relErr := filepath.Rel(home, path)
		if relErr == nil && !strings.HasPrefix(rel, ".") && !strings.Contains(rel, "/.") {
			out = append(out, rel)
		}
		return nil
	})
	return out, err
}

func isHeavyFileSearchDir(name string) bool {
	switch name {
	case "go", "paru", "node_modules", "target", ".cache", ".local", ".mozilla", ".npm", ".cargo", ".rustup":
		return true
	default:
		return false
	}
}

func filePrompt(mode string) string {
	if mode == "open-dir" {
		return "Dir> "
	}
	if mode == "open-terminal" {
		return "Term dir> "
	}
	return "File> "
}

func sshHosts(home string) []string {
	seen := map[string]bool{}
	add := func(host string) {
		if host != "" && !strings.ContainsAny(host, "*?") {
			seen[host] = true
		}
	}
	if data, err := os.ReadFile(filepath.Join(home, ".ssh", "config")); err == nil {
		for _, line := range strings.Split(string(data), "\n") {
			fields := strings.Fields(line)
			if len(fields) > 1 && strings.EqualFold(fields[0], "host") {
				for _, h := range fields[1:] {
					add(h)
				}
			}
		}
	}
	if data, err := os.ReadFile(filepath.Join(home, ".ssh", "known_hosts")); err == nil {
		for _, line := range strings.Split(string(data), "\n") {
			field := strings.FieldsFunc(line, func(r rune) bool { return r == ' ' || r == ',' })
			if len(field) > 0 && !strings.HasPrefix(field[0], "|") {
				add(strings.Trim(strings.TrimPrefix(field[0], "["), "]"))
			}
		}
	}
	out := []string{}
	for host := range seen {
		out = append(out, host)
	}
	return out
}

func rofiText(prompt, initial string, stderr io.Writer) (string, error) {
	cmd := exec.Command("rofi", "-dmenu", "-i", "-p", prompt)
	cmd.Stdin = strings.NewReader(initial)
	cmd.Stderr = stderr
	data, err := cmd.Output()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(data)), nil
}

func browserCandidates() []string {
	candidates := []string{}
	for _, name := range []string{"chromium", "brave", "brave-browser"} {
		if commandExists(name) {
			candidates = append(candidates, name)
		}
	}
	if commandExists("flatpak") && flatpakAppExists("com.brave.Browser") {
		candidates = append(candidates, "flatpak:com.brave.Browser")
	}
	if len(candidates) == 0 {
		candidates = append(candidates, "chromium")
	}
	return candidates
}

func rofiPick(prompt string, labels []string, stderr io.Writer) (string, error) {
	args := []string{"-dmenu", "-i", "-p", prompt}
	if themePath := rofiMenuThemePath(); themePath != "" {
		args = append(args, "-theme", themePath)
	}
	if theme := rofiMenuThemeStr(); theme != "" {
		args = append(args, "-theme-str", theme)
	}
	cmd := exec.Command("rofi", args...)
	cmd.Stdin = strings.NewReader(strings.Join(labels, "\n") + "\n")
	cmd.Stderr = stderr
	data, err := cmd.Output()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(data)), nil
}

func rofiMenuThemePath() string {
	path := os.Getenv("HYPR_ROFI_THEME")
	if path == "" {
		path = filepath.Join(os.Getenv("HOME"), ".config", "rofi", "hypr-menu.rasi")
	}
	if _, err := os.Stat(path); err != nil {
		return ""
	}
	return path
}

func rofiMenuThemeStr() string {
	renv := loadRofiEnv()
	scale := rofiFloat(renv, "HYPR_ROFI_SCALE", 1)
	fontSize := rofiInt(renv, "HYPR_ROFI_FONT_SIZE", int(12*scale))
	width := rofiInt(renv, "HYPR_ROFI_WIDTH", int(600*scale))
	lines := rofiInt(renv, "HYPR_ROFI_LINES", 8)
	padding := rofiInt(renv, "HYPR_ROFI_PADDING", int(8*scale))
	iconSize := rofiInt(renv, "HYPR_ROFI_ICON_SIZE", int(32*scale))
	return fmt.Sprintf(`configuration { font: "JetBrainsMono Nerd Font %d"; } * { width: %dpx; } listview { lines: %d; } element { padding: %dpx; } element-icon { size: %dpx; }`, fontSize, width, lines, padding, iconSize)
}

func dmenuPick(kind, prompt string, labels []string, stderr io.Writer) (string, error) {
	var args []string
	switch kind {
	case "walker":
		args = []string{"--dmenu", "-p", strings.TrimSpace(prompt)}
	case "rofi":
		args = []string{"-dmenu", "-i", "-p", strings.TrimSpace(prompt)}
	default:
		kind = "fuzzel"
		args = fuzzelDmenuArgs(prompt, 72, 14)
	}
	cmd := exec.Command(kind, args...)
	cmd.Stdin = strings.NewReader(strings.Join(labels, "\n") + "\n")
	cmd.Stderr = stderr
	data, err := cmd.Output()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(data)), nil
}

func fuzzelDmenuArgs(prompt string, baseWidth, baseLines int) []string {
	fenv := loadFuzzelEnv()
	scale := fuzzelFloat(fenv, "HYPR_FUZZEL_SCALE", 1)
	return []string{
		"--dmenu",
		"--prompt", prompt,
		fmt.Sprintf("--font=JetBrainsMono Nerd Font:size=%d", fuzzelInt(fenv, "HYPR_FUZZEL_FONT_SIZE", int(12*scale))),
		"--width", strconv.Itoa(fuzzelInt(fenv, "HYPR_FUZZEL_WIDTH", int(float64(baseWidth)*scale))),
		"--lines", strconv.Itoa(fuzzelInt(fenv, "HYPR_FUZZEL_LINES", int(float64(baseLines)*scale))),
		"--line-height", strconv.Itoa(fuzzelInt(fenv, "HYPR_FUZZEL_LINE_HEIGHT", int(22*scale))),
	}
}

func runOrPrintCommand(command windows.Command, printOnly bool, stdout, stderr io.Writer) error {
	if printOnly {
		fmt.Fprintln(stdout, shellCommand(command.Name, command.Args))
		return nil
	}
	cmd := exec.Command(command.Name, command.Args...)
	cmd.Stdout = stdout
	cmd.Stderr = stderr
	return cmd.Run()
}

func runSilent(name string, args []string, stderr io.Writer) error {
	cmd := exec.Command(name, args...)
	cmd.Stderr = stderr
	return cmd.Run()
}

func parsePIDRSS(value string) map[int]int {
	out := map[int]int{}
	for _, part := range strings.Split(value, ",") {
		pidText, rssText, ok := strings.Cut(strings.TrimSpace(part), "=")
		if !ok {
			continue
		}
		pid, pidErr := strconv.Atoi(pidText)
		rss, rssErr := strconv.Atoi(rssText)
		if pidErr == nil && rssErr == nil {
			out[pid] = rss
		}
	}
	return out
}

func procRSSOwned(pid int) (int, bool) {
	data, err := os.ReadFile(filepath.Join("/proc", strconv.Itoa(pid), "status"))
	if err != nil {
		return 0, false
	}
	uid := strconv.Itoa(os.Getuid())
	rss := 0
	owned := false
	for _, line := range strings.Split(string(data), "\n") {
		fields := strings.Fields(line)
		if len(fields) >= 2 && fields[0] == "Uid:" {
			owned = fields[1] == uid
		}
		if len(fields) >= 2 && fields[0] == "VmRSS:" {
			rss, _ = strconv.Atoi(fields[1])
		}
	}
	return rss, owned
}

func queryPamixerState(mic bool) osd.DeviceState {
	args := []string{}
	if mic {
		args = append(args, "--default-source")
	}
	volume := commandOutputInt("pamixer", append(args, "--get-volume")...)
	muted := strings.TrimSpace(commandOutputString("pamixer", append(args, "--get-mute")...)) == "true"
	return osd.DeviceState{Volume: volume, Muted: muted}
}

func queryBrightnessPercent() int {
	out := commandOutputString("brightnessctl", "-m")
	fields := strings.Split(out, ",")
	if len(fields) < 4 {
		return 0
	}
	percent := strings.TrimSuffix(strings.TrimSpace(fields[3]), "%")
	value, _ := strconv.Atoi(percent)
	return value
}

func commandOutputInt(name string, args ...string) int {
	value, _ := strconv.Atoi(strings.TrimSpace(commandOutputString(name, args...)))
	return value
}

func commandOutputString(name string, args ...string) string {
	data, err := exec.Command(name, args...).Output()
	if err != nil {
		return ""
	}
	return string(data)
}

func runCommand(name string, args []string, stdout, stderr io.Writer, background bool) error {
	if name == "" {
		return nil
	}
	cmd := exec.Command(name, args...)
	cmd.Stdout = stdout
	cmd.Stderr = stderr
	if background {
		return cmd.Start()
	}
	return cmd.Run()
}

func printWebappCreatePlan(stdout io.Writer, plan webapp.CreatePlanData) {
	fmt.Fprintf(stdout, "slug=%s\nurl=%s\ndesktop=%s\nlauncher=%s\nicon=%s\nprofile=%s\n", plan.Slug, plan.URL, plan.DesktopPath, plan.LauncherPath, plan.IconPath, plan.ProfilePath)
}

func writeWebappCreatePlan(plan webapp.CreatePlanData) error {
	if err := os.MkdirAll(filepath.Dir(plan.DesktopPath), 0o700); err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(plan.LauncherPath), 0o700); err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(plan.IconPath), 0o700); err != nil {
		return err
	}
	if err := os.WriteFile(plan.LauncherPath, []byte(plan.LauncherContent), 0o755); err != nil {
		return err
	}
	return os.WriteFile(plan.DesktopPath, []byte(plan.DesktopContent), 0o644)
}

func runSmartRunWithIO(args []string, stdout, stderr io.Writer) error {
	if len(args) < 1 {
		return cli.UsageError("usage: orgm-hypr smart-run [parse|run] QUERY...")
	}
	switch args[0] {
	case "parse":
		if len(args) < 2 {
			return cli.UsageError("usage: orgm-hypr smart-run parse QUERY...")
		}
		printSmartRunPlan(stdout, smartrun.Parse(strings.Join(args[1:], " "), commandExists))
		return nil
	case "run":
		query, printOnly, printExec, err := parseSmartRunArgs(args[1:])
		if err != nil {
			return cli.UsageError(err.Error())
		}
		if query == "" && !printOnly && !printExec {
			picked, _ := dmenuPick("fuzzel", "Search or URL> ", []string{"!a ChatGPT", "!c Claude", "!g Google", "!y YouTube"}, stderr)
			query = strings.TrimSpace(picked)
			if query == "" {
				return nil
			}
		}
		if query == "" {
			return cli.UsageError("usage: orgm-hypr smart-run run QUERY... [--print|--print-exec]")
		}
		plan := smartrun.Parse(query, commandExists)
		if printOnly {
			printSmartRunPlan(stdout, plan)
			return nil
		}
		execPlan := smartrun.BuildExecutionPlan(plan, smartrun.Env{Browser: envDefault("BROWSER", "chromium"), Home: os.Getenv("HOME"), HasWLCopy: commandExists("wl-copy"), HasGIO: commandExists("gio")})
		if printExec {
			printExecutionPlan(stdout, execPlan)
			return nil
		}
		return runExecutionPlan(execPlan, stdout, stderr)
	default:
		return cli.UsageError("usage: orgm-hypr smart-run [parse|run] QUERY...")
	}
}

func parseSmartRunArgs(args []string) (string, bool, bool, error) {
	printOnly := false
	printExec := false
	query := []string{}
	for _, arg := range args {
		switch arg {
		case "--print":
			printOnly = true
		case "--print-exec":
			printExec = true
		default:
			if strings.HasPrefix(arg, "--") {
				return "", false, false, fmt.Errorf("unknown flag: %s", arg)
			}
			query = append(query, arg)
		}
	}
	return strings.Join(query, " "), printOnly, printExec, nil
}

func commandExists(name string) bool {
	_, err := exec.LookPath(name)
	return err == nil
}

func envDefault(name, fallback string) string {
	if value := os.Getenv(name); value != "" {
		return value
	}
	return fallback
}

func loadFuzzelEnv() map[string]string {
	path := os.Getenv("HYPR_FUZZEL_ENV")
	if path == "" {
		path = filepath.Join(os.Getenv("HOME"), ".config", "fuzzel", "fuzzel.env")
	}
	return loadSimpleEnv(path)
}

func loadRofiEnv() map[string]string {
	path := os.Getenv("HYPR_ROFI_ENV")
	if path == "" {
		path = filepath.Join(os.Getenv("HOME"), ".config", "rofi", "hypr-menu.env")
	}
	return loadSimpleEnv(path)
}

func loadSimpleEnv(path string) map[string]string {
	data, err := os.ReadFile(path)
	if err != nil {
		return map[string]string{}
	}
	out := map[string]string{}
	for _, line := range strings.Split(string(data), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		key, value, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		out[strings.TrimSpace(key)] = strings.Trim(strings.TrimSpace(value), "\"'")
	}
	return out
}

func fuzzelFloat(env map[string]string, name string, fallback float64) float64 {
	return envFloat(env, name, fallback)
}

func fuzzelInt(env map[string]string, name string, fallback int) int {
	return envInt(env, name, fallback)
}

func rofiFloat(env map[string]string, name string, fallback float64) float64 {
	return envFloat(env, name, fallback)
}

func rofiInt(env map[string]string, name string, fallback int) int {
	return envInt(env, name, fallback)
}

func envFloat(env map[string]string, name string, fallback float64) float64 {
	value := firstNonEmpty(os.Getenv(name), env[name])
	if value == "" {
		return fallback
	}
	parsed, err := strconv.ParseFloat(value, 64)
	if err != nil || parsed <= 0 {
		return fallback
	}
	return parsed
}

func envInt(env map[string]string, name string, fallback int) int {
	value := firstNonEmpty(os.Getenv(name), env[name])
	if value == "" {
		return fallback
	}
	parsed, err := strconv.Atoi(value)
	if err != nil || parsed <= 0 {
		return fallback
	}
	return parsed
}

func printExecutionPlan(stdout io.Writer, plan smartrun.ExecutionPlan) {
	for _, command := range plan.Commands {
		fmt.Fprintln(stdout, shellCommand(command.Name, command.Args))
	}
}

func runExecutionPlan(plan smartrun.ExecutionPlan, stdout, stderr io.Writer) error {
	for _, command := range plan.Commands {
		if command.Name == "" {
			continue
		}
		cmd := exec.Command(command.Name, command.Args...)
		cmd.Stdout = stdout
		cmd.Stderr = stderr
		if command.Stdin != "" {
			cmd.Stdin = strings.NewReader(command.Stdin)
		}
		if plan.Background {
			if err := cmd.Start(); err != nil {
				return err
			}
			continue
		}
		if err := cmd.Run(); err != nil {
			return err
		}
	}
	return nil
}

func printSmartRunPlan(stdout io.Writer, plan smartrun.Plan) {
	fmt.Fprintf(stdout, "kind=%s\n", plan.Kind)
	if plan.URL != "" {
		fmt.Fprintf(stdout, "url=%s\n", plan.URL)
	}
	if plan.Desktop != "" {
		fmt.Fprintf(stdout, "desktop=%s\n", plan.Desktop)
	}
	if plan.Query != "" {
		fmt.Fprintf(stdout, "query=%s\n", plan.Query)
	}
	if plan.Command != "" {
		fmt.Fprintf(stdout, "command=%s\n", plan.Command)
	}
}

func parseFocusArgs(args []string) (string, bool, error) {
	printOnly := false
	positionals := []string{}
	for _, arg := range args {
		switch arg {
		case "--print":
			printOnly = true
		default:
			if strings.HasPrefix(arg, "--") {
				return "", false, fmt.Errorf("unknown flag: %s", arg)
			}
			positionals = append(positionals, arg)
		}
	}
	if len(positionals) != 1 {
		return "", false, fmt.Errorf("usage: orgm-hypr windows focus ADDRESS [--print]")
	}
	return positionals[0], printOnly, nil
}

func readHyprClientsJSON(path string) ([]byte, error) {
	if path != "" {
		return os.ReadFile(path)
	}
	return exec.Command("hyprctl", "-j", "clients").Output()
}

func notifyArgs(payload osd.NotifyPayload) []string {
	return []string{"-a", payload.App, "-h", "string:x-canonical-private-synchronous:" + payload.SyncID, "-h", fmt.Sprintf("int:value:%d", payload.Value), "-t", strconv.Itoa(payload.TimeoutMS), payload.Title, ""}
}

func shellCommand(name string, args []string) string {
	return strings.Join(append([]string{name}, args...), " ")
}

func runWallpaper(args []string) error {
	return runWallpaperWithIO(args, os.Stdout, os.Stderr)
}

func runWallpaperWithIO(args []string, stdout, stderr io.Writer) error {
	m := wallpaper.NewManager(stdout, stderr)
	if len(args) < 1 {
		return m.Restore()
	}

	switch args[0] {
	case "data":
		flags := flag.NewFlagSet("orgm-hypr wallpaper data", flag.ContinueOnError)
		flags.SetOutput(stderr)
		var opts wallpaper.DataOptions
		var scriptArgs csvFlag
		flags.StringVar(&opts.Mode, "mode", "", "wallpaper mode: static or video")
		flags.StringVar(&opts.ManifestPath, "manifest", "", "TSV manifest path")
		flags.StringVar(&opts.JSONPath, "json", "", "Quickshell JSON output path")
		flags.StringVar(&opts.CurrentPath, "current", "", "current wallpaper path")
		flags.StringVar(&opts.Script, "script", "orgm-hypr", "script/command used by Quickshell apply actions")
		flags.Var(&scriptArgs, "script-arg", "extra script argument for Quickshell actions; may be repeated")
		if err := flags.Parse(args[1:]); err != nil {
			return cli.UsageError(err.Error())
		}
		if flags.NArg() != 0 {
			return cli.UsageError("unexpected argument: %s", flags.Arg(0))
		}
		opts.ScriptArgs = []string(scriptArgs)
		return wallpaper.GeneratePickerData(opts)
	case "clean-thumbs":
		flags := flag.NewFlagSet("orgm-hypr wallpaper clean-thumbs", flag.ContinueOnError)
		flags.SetOutput(stderr)
		var root string
		flags.StringVar(&root, "root", "", "wallpaper root containing folder-local .thumb caches")
		if err := flags.Parse(args[1:]); err != nil {
			return cli.UsageError(err.Error())
		}
		if flags.NArg() != 0 {
			return cli.UsageError("unexpected argument: %s", flags.Arg(0))
		}
		if root == "" {
			return cli.UsageError("root path is required")
		}
		return wallpaper.CleanStaleThumbnails(root)
	case "status":
		return m.Status()
	case "current":
		path, err := m.CompatibilityCurrent()
		if err != nil {
			return err
		}
		fmt.Fprintln(stdout, path)
		return nil
	case "restore":
		return m.Restore()
	case "set-static":
		if len(args) < 2 {
			return cli.UsageError("usage: orgm-hypr wallpaper set-static PATH")
		}
		return m.SetStatic(args[1], "static")
	case "set-video":
		if len(args) < 2 {
			return cli.UsageError("usage: orgm-hypr wallpaper set-video PATH")
		}
		return m.SetVideo(args[1])
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
	case "pick", "next", "change":
		return m.MenuPick()
	case "carousel":
		if len(args) < 2 {
			return cli.UsageError("usage: orgm-hypr wallpaper carousel [static|video]")
		}
		return m.OpenQuickshellCarousel(args[1])
	case "warm-thumbs":
		if len(args) < 2 {
			return cli.UsageError("usage: orgm-hypr wallpaper warm-thumbs [static|video] [index]")
		}
		index := "0"
		if len(args) > 2 {
			index = args[2]
		}
		return m.WarmThumbs(args[1], index, 5)
	case "warm-page":
		if len(args) < 2 {
			return cli.UsageError("usage: orgm-hypr wallpaper warm-page [static|video] [page] [page-size]")
		}
		page := parseIntDefault(argAt(args, 2), 0)
		pageSize := parseIntDefault(argAt(args, 3), 16)
		return m.WarmPage(args[1], page, pageSize)
	case "picker-daemon":
		return m.StartQuickshellPicker(false)
	case "daemon":
		return m.RunDaemon()
	default:
		return cli.UsageError("usage: orgm-hypr wallpaper [restore|current|pick|random static|random video|carousel static|carousel video|set-static PATH|set-video PATH|status]")
	}
}

func argAt(args []string, idx int) string {
	if len(args) > idx {
		return args[idx]
	}
	return ""
}

func parseIntDefault(value string, fallback int) int {
	if value == "" {
		return fallback
	}
	parsed, err := strconv.Atoi(value)
	if err != nil {
		return fallback
	}
	return parsed
}

type csvFlag []string

func (f *csvFlag) String() string { return fmt.Sprint([]string(*f)) }

func (f *csvFlag) Set(value string) error {
	*f = append(*f, value)
	return nil
}

func usage() string {
	return "usage: orgm-hypr [version|wallpaper|theme|session|waybar|calendar|dock|windows|zen|osd|menu|helper|updates|webapp|notify|smart-run|launcher|fuzzel|file|ssh|tmux|calc|pi|obsidian] ..."
}
