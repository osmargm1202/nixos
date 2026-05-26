package session

import (
	"reflect"
	"testing"
)

func TestImportEnvCommandsMatchAutostartEnvImport(t *testing.T) {
	commands := ImportEnvCommands()

	if len(commands) != 2 {
		t.Fatalf("ImportEnvCommands len = %d, want 2", len(commands))
	}
	if commands[0].Name != "systemctl" || commands[0].Args[0] != "--user" || commands[0].Args[1] != "import-environment" {
		t.Fatalf("first command = %#v, want systemctl --user import-environment", commands[0])
	}
	if commands[1].Name != "dbus-update-activation-environment" || commands[1].Args[0] != "--systemd" {
		t.Fatalf("second command = %#v, want dbus-update-activation-environment --systemd", commands[1])
	}
	if !reflect.DeepEqual(commands[0].Args[2:], EnvVars) || !reflect.DeepEqual(commands[1].Args[1:], EnvVars) {
		t.Fatalf("env vars mismatch: systemctl=%#v dbus=%#v want %#v", commands[0].Args, commands[1].Args, EnvVars)
	}
}

func TestContainerStartCommandPrefersDockerThenPodman(t *testing.T) {
	cmd, ok := ContainerStartCommand([]string{"arch", "windows"}, func(name string) bool { return name == "docker" })
	if !ok {
		t.Fatalf("ContainerStartCommand(docker) ok = false")
	}
	wantArgs := []string{"start", "arch", "windows"}
	if cmd.Name != "docker" || !reflect.DeepEqual(cmd.Args, wantArgs) {
		t.Fatalf("docker command = %#v, want docker %#v", cmd, wantArgs)
	}

	cmd, ok = ContainerStartCommand([]string{"arch"}, func(name string) bool { return name == "podman" })
	if !ok || cmd.Name != "podman" || !reflect.DeepEqual(cmd.Args, []string{"start", "arch"}) {
		t.Fatalf("podman command = %#v ok=%t, want podman start arch", cmd, ok)
	}
}

func TestDiscordCommandPrefersNativeThenFlatpak(t *testing.T) {
	cmd, ok := DiscordCommand(func(name string) bool { return name == "discord" }, func(app string) bool { return false })
	if !ok || cmd.Name != "discord" || !reflect.DeepEqual(cmd.Args, []string{"--start-minimized"}) {
		t.Fatalf("native discord command = %#v ok=%t", cmd, ok)
	}

	cmd, ok = DiscordCommand(func(name string) bool { return name == "flatpak" }, func(app string) bool { return app == "com.discordapp.Discord" })
	if !ok || cmd.Name != "flatpak" || !reflect.DeepEqual(cmd.Args, []string{"run", "com.discordapp.Discord", "--start-minimized"}) {
		t.Fatalf("flatpak discord command = %#v ok=%t", cmd, ok)
	}
}
