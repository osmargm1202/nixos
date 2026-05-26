package dock

import "path/filepath"

type Env struct {
	Home             string
	IconSize         string
	MarginRight      string
	MarginTop        string
	MarginBottom     string
	LauncherPosition string
	LauncherIcon     string
	LauncherCommand  string
}

type StartState struct {
	BinaryFound    bool
	AlreadyRunning bool
	Reload         bool
	Env            Env
}

type StartPlan struct {
	ExitCode      int
	KillExisting  bool
	ExecArgs      []string
	Notifications []string
}

func StartArgs(env Env) []string {
	return []string{
		"-r",
		"-p", "right",
		"-a", "center",
		"-i", defaultString(env.IconSize, "56"),
		"-x",
		"-mr", defaultString(env.MarginRight, "8"),
		"-mt", defaultString(env.MarginTop, "0"),
		"-mb", defaultString(env.MarginBottom, "0"),
		"-lp", defaultString(env.LauncherPosition, "start"),
		"-ico", defaultString(env.LauncherIcon, filepath.Join(env.Home, ".local", "share", "icons", "nixos.svg")),
		"-c", defaultString(env.LauncherCommand, "orgm-hypr menu main"),
	}
}

func PlanStart(state StartState) StartPlan {
	if !state.BinaryFound {
		return StartPlan{ExitCode: 1, Notifications: []string{"nwg-dock-hyprland is not installed yet"}}
	}
	plan := StartPlan{ExitCode: 0}
	if state.Reload {
		plan.KillExisting = true
	}
	if state.AlreadyRunning {
		return plan
	}
	plan.ExecArgs = StartArgs(state.Env)
	return plan
}

func defaultString(value, fallback string) string {
	if value != "" {
		return value
	}
	return fallback
}
