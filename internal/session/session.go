package session

type Command struct {
	Name string
	Args []string
}

var EnvVars = []string{
	"WAYLAND_DISPLAY",
	"DISPLAY",
	"XDG_SESSION_TYPE",
	"XDG_SESSION_DESKTOP",
	"XDG_CURRENT_DESKTOP",
	"QT_QPA_PLATFORM",
	"QT_QPA_PLATFORMTHEME",
	"QT_QPA_PLATFORMTHEME_QT6",
	"ELECTRON_OZONE_PLATFORM_HINT",
	"MOZ_ENABLE_WAYLAND",
	"NIXOS_OZONE_WL",
	"TERMINAL",
	"XCURSOR_THEME",
	"XCURSOR_SIZE",
}

func ImportEnvCommands() []Command {
	return []Command{
		{Name: "systemctl", Args: append([]string{"--user", "import-environment"}, EnvVars...)},
		{Name: "dbus-update-activation-environment", Args: append([]string{"--systemd"}, EnvVars...)},
	}
}

func ContainerStartCommand(names []string, commandExists func(string) bool) (Command, bool) {
	for _, engine := range []string{"docker", "podman"} {
		if commandExists(engine) {
			return Command{Name: engine, Args: append([]string{"start"}, names...)}, true
		}
	}
	return Command{}, false
}

func DiscordCommand(commandExists func(string) bool, flatpakInfo func(string) bool) (Command, bool) {
	if commandExists("discord") {
		return Command{Name: "discord", Args: []string{"--start-minimized"}}, true
	}
	if commandExists("flatpak") && flatpakInfo("com.discordapp.Discord") {
		return Command{Name: "flatpak", Args: []string{"run", "com.discordapp.Discord", "--start-minimized"}}, true
	}
	return Command{}, false
}
