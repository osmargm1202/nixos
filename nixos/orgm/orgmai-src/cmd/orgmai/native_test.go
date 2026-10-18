package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func TestSavedPiExecutesNativeInterfaceWithoutLegacyOverrides(t *testing.T) {
	a, bin, shell := launcherFixture(t)
	legacy := `{"program":"pi","provider":"legacy","model":"legacy-model","thinking":"high"}`
	if err := os.MkdirAll(filepath.Dir(a.configPath), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(a.configPath, []byte(legacy), 0600); err != nil {
		t.Fatal(err)
	}
	agent := filepath.Join(os.Getenv("HOME"), ".pi/agent")
	if err := os.MkdirAll(agent, 0700); err != nil {
		t.Fatal(err)
	}
	for name, content := range map[string]string{"settings.json": "native-settings\n", "auth.json": "native-auth\n"} {
		if err := os.WriteFile(filepath.Join(agent, name), []byte(content), 0600); err != nil {
			t.Fatal(err)
		}
	}
	launcherScript(t, bin, "pi", shell, `
[ "$#" -eq 1 ] && [ "$1" = '-ne' ] || exit 21
[ -z "${PI_PACKAGE_DIR-}" ] || exit 22
IFS= read -r settings < "$HOME/.pi/agent/settings.json"
IFS= read -r auth < "$HOME/.pi/agent/auth.json"
[ "$settings" = native-settings ] && [ "$auth" = native-auth ] || exit 23
IFS= read -r line
printf 'native Pi input: %s\n' "$line"
`)
	command := exec.Command(os.Args[0], "-test.run=^TestLauncherExecHelper$")
	command.Env = append(os.Environ(), "ORGM_LAUNCHER_TEST=1", "PI_PACKAGE_DIR=other-agent")
	command.Stdin = strings.NewReader("terminal input\n")
	output, err := command.CombinedOutput()
	if err != nil || string(output) != "native Pi input: terminal input\n" {
		t.Fatalf("native Pi launch: %q, %v", output, err)
	}
	after, _ := os.ReadFile(a.configPath)
	if string(after) != legacy {
		t.Fatal("launch should not rewrite the saved choice or legacy preferences")
	}
	for name, content := range map[string]string{"settings.json": "native-settings\n", "auth.json": "native-auth\n"} {
		data, _ := os.ReadFile(filepath.Join(agent, name))
		if string(data) != content {
			t.Fatal("launcher modified native preferences", name)
		}
	}
	if _, err := os.Stat(filepath.Join(os.Getenv("XDG_STATE_HOME"), "orgmai/sessions")); !os.IsNotExist(err) {
		t.Fatalf("launcher should not create its own sessions: %v", err)
	}
}

func TestConfigChangesProgramWithoutStartingPiOrChoosingModels(t *testing.T) {
	a, bin, shell := launcherFixture(t)
	launcherScript(t, bin, "pi", shell, "exit 21\n")
	launcherScript(t, bin, "gum", shell, "printf 'Pi\\n'\n")
	if err := a.run([]string{"config"}); err != nil {
		t.Fatal(err)
	}
	data, _ := os.ReadFile(a.configPath)
	if string(data) != "{\n  \"program\": \"pi\"\n}\n" {
		t.Fatalf("launcher must only save the executable choice: %s", data)
	}
}

func TestCopiedShellWrapperDoesNotCountAsAnInstalledClient(t *testing.T) {
	_, bin, shell := launcherFixture(t)
	launcherScript(t, bin, "claude", shell, "# Skip this wrapper and execute the next Claude binary on PATH.\nexit 21\n")
	if _, err := findProgram("claude"); err == nil {
		t.Fatal("orphan copied wrapper was counted as an installation")
	}
	native := filepath.Join(os.Getenv("HOME"), ".bun/bin")
	launcherScript(t, native, "claude", shell, "exit 0\n")
	path, err := findProgram("claude")
	if err != nil || path != filepath.Join(native, "claude") {
		t.Fatalf("native client not found behind personal wrapper: %q, %v", path, err)
	}
}

func TestPiFindsFNMInterpreterWithoutShellInitialization(t *testing.T) {
	envPath, err := exec.LookPath("env")
	if err != nil {
		t.Fatal(err)
	}
	a, _, shell := launcherFixture(t)
	bin := filepath.Join(os.Getenv("XDG_DATA_HOME"), "fnm/aliases/default/bin")
	launcherScript(t, bin, "pi", envPath+" node", "")
	launcherScript(t, bin, "node", shell, "[ \"$#\" -eq 2 ] && [ \"$2\" = '-ne' ] || exit 21\nprintf 'native interpreter\\n'\n")
	if err := a.saveConfig(config{Program: "pi"}); err != nil {
		t.Fatal(err)
	}
	command := exec.Command(os.Args[0], "-test.run=^TestLauncherExecHelper$")
	command.Env = append(os.Environ(), "ORGM_LAUNCHER_TEST=1")
	output, err := command.CombinedOutput()
	if err != nil || string(output) != "native interpreter\n" {
		t.Fatalf("Pi could not use its native interpreter: %q, %v", output, err)
	}
}
