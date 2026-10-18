package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

func launcherFixture(t *testing.T) (*app, string, string) {
	t.Helper()
	shell, err := exec.LookPath("sh")
	if err != nil {
		t.Fatal(err)
	}
	home := isolatedNativeRuntime(t)
	bin := filepath.Join(home, "bin")
	if err := os.MkdirAll(bin, 0700); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", bin)
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, "config"))
	t.Setenv("XDG_STATE_HOME", filepath.Join(home, "state"))
	t.Setenv("MENU_LOG", filepath.Join(home, "menu"))
	a, err := newApp()
	if err != nil {
		t.Fatal(err)
	}
	return a, bin, shell
}

func launcherScript(t *testing.T, directory, name, shell, body string) {
	t.Helper()
	if err := os.MkdirAll(directory, 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(directory, name), []byte("#!"+shell+"\n"+body), 0700); err != nil {
		t.Fatal(err)
	}
}

func TestFirstLaunchChoosesAllFiveProgramsAndRemembersChoiceWithoutPi(t *testing.T) {
	a, bin, shell := launcherFixture(t)
	launcherScript(t, bin, "codex", shell, "exit 0\n")
	launcherScript(t, bin, "gum", shell, `
while IFS= read -r line; do printf '%s\n' "$line" >> "$MENU_LOG"; done
printf 'Codex\n'
`)
	// Legacy model choices are discarded when saving a new program choice.
	if err := os.MkdirAll(filepath.Dir(a.configPath), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(a.configPath, []byte(`{"provider":"personal","model":"existing-model","thinking":"high"}`), 0600); err != nil {
		t.Fatal(err)
	}
	cfg, cancelled, err := a.chooseProgram(false)
	if err != nil || cancelled || cfg.Program != "codex" {
		t.Fatalf("first launch: %+v, %v, %v", cfg, cancelled, err)
	}
	menu, _ := os.ReadFile(os.Getenv("MENU_LOG"))
	for _, name := range []string{"Claude", "Codex", "OpenCode", "OMP", "Pi"} {
		if !strings.Contains(string(menu), name) {
			t.Fatalf("missing choice %s: %s", name, menu)
		}
	}
	info, err := os.Stat(a.configPath)
	if err != nil || info.Mode().Perm() != 0600 {
		t.Fatalf("configuration must be private: %v, %v", info, err)
	}
	stored, _ := os.ReadFile(a.configPath)
	if strings.Contains(string(stored), "model") || strings.Contains(string(stored), "provider") {
		t.Fatalf("launcher still saves model preferences: %s", stored)
	}
	if err := os.Remove(filepath.Join(bin, "gum")); err != nil {
		t.Fatal(err)
	}
	cfg, cancelled, err = a.chooseProgram(false)
	if err != nil || cancelled || cfg.Program != "codex" {
		t.Fatalf("saved choice prompted again: %+v, %v, %v", cfg, cancelled, err)
	}
}

func TestCancelProgramChangePreservesPreviousConfiguration(t *testing.T) {
	a, bin, shell := launcherFixture(t)
	if err := a.saveConfig(config{Program: "codex"}); err != nil {
		t.Fatal(err)
	}
	before, _ := os.ReadFile(a.configPath)
	launcherScript(t, bin, "gum", shell, "exit 130\n")
	_, cancelled, err := a.chooseProgram(true)
	after, _ := os.ReadFile(a.configPath)
	if err != nil || !cancelled || string(before) != string(after) {
		t.Fatalf("cancel changed preferences: %v, %v", cancelled, err)
	}
}

func TestMissingProgramShowsInstallHintAndDoesNotSaveAFallback(t *testing.T) {
	a, bin, shell := launcherFixture(t)
	launcherScript(t, bin, "gum", shell, `
printf '%s\n' "$@" >> "$MENU_LOG"
if [ -f "$MENU_LOG.once" ]; then exit 130; fi
: > "$MENU_LOG.once"
printf 'Claude (no instalado)\n'
`)
	_, cancelled, err := a.chooseProgram(false)
	if err != nil || !cancelled {
		t.Fatalf("missing program was not cancellable: %v, %v", cancelled, err)
	}
	if _, err := os.Stat(a.configPath); !os.IsNotExist(err) {
		t.Fatalf("missing program persisted a selection: %v", err)
	}
	log, _ := os.ReadFile(os.Getenv("MENU_LOG"))
	if !strings.Contains(string(log), "claude-install") {
		t.Fatalf("missing installation hint: %s", log)
	}
}

func TestNativeClientInBunDirectoryIsFoundWithoutInteractiveShell(t *testing.T) {
	_, _, shell := launcherFixture(t)
	bin := filepath.Join(os.Getenv("HOME"), ".bun", "bin")
	launcherScript(t, bin, "codex", shell, "exit 0\n")
	path, err := findProgram("codex")
	if err != nil || path != filepath.Join(bin, "codex") {
		t.Fatalf("desktop cannot find native client: %q, %v", path, err)
	}
}

func TestEveryRequestedProgramCanBeSelected(t *testing.T) {
	for _, program := range chatPrograms {
		t.Run(program.id, func(t *testing.T) {
			a, bin, shell := launcherFixture(t)
			launcherScript(t, bin, program.id, shell, "exit 0\n")
			launcherScript(t, bin, "gum", shell, "printf '%s\\n' '"+program.label+"'\n")
			cfg, cancelled, err := a.chooseProgram(false)
			if err != nil || cancelled || cfg.Program != program.id {
				t.Fatalf("selection: %+v, %v, %v", cfg, cancelled, err)
			}
		})
	}
}

func TestOMPUsesItsOwnPackageAssetsAndASingleRuntimePath(t *testing.T) {
	_, bin, shell := launcherFixture(t)
	root := filepath.Join(os.Getenv("HOME"), "omp-package")
	launcherScript(t, filepath.Join(root, "dist"), "cli.js", shell, "exit 0\n")
	if err := os.WriteFile(filepath.Join(root, "package.json"), []byte("{}"), 0600); err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(bin, "omp")
	if err := os.Symlink(filepath.Join(root, "dist", "cli.js"), path); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PI_PACKAGE_DIR", "another-agent")
	paths, packages := 0, 0
	for _, value := range programEnvironment("omp", path) {
		if strings.HasPrefix(value, "PATH=") {
			paths++
			if !strings.HasPrefix(value, "PATH="+bin+string(os.PathListSeparator)) {
				t.Fatalf("missing native runtime: %s", value)
			}
		}
		if strings.HasPrefix(value, "PI_PACKAGE_DIR=") {
			packages++
			if value != "PI_PACKAGE_DIR="+root {
				t.Fatalf("wrong OMP assets: %s", value)
			}
		}
	}
	if paths != 1 || packages != 1 {
		t.Fatalf("duplicate/missing runtime entries: %d paths, %d asset roots", paths, packages)
	}
}

func TestNativeConversationArguments(t *testing.T) {
	for _, item := range []struct {
		program         string
		input, expected []string
	}{
		{"codex", []string{"new"}, nil},
		{"codex", nil, nil},
		{"codex", []string{"prev"}, []string{"resume"}},
		{"claude", []string{"prev"}, []string{"--resume"}},
		{"omp", []string{"prev"}, []string{"--resume"}},
		{"omp", nil, nil},
		{"opencode", []string{"prev"}, []string{"--continue"}},
		{"opencode", []string{"new", "literal $(payload)"}, []string{"literal $(payload)"}},
		{"claude", []string{"new", "a question"}, []string{"a question"}},
		{"pi", nil, []string{"-ne"}},
		{"pi", []string{"new"}, []string{"-ne"}},
		{"pi", []string{"chat"}, []string{"-ne"}},
		{"pi", []string{"prev"}, []string{"-ne", "--resume"}},
		{"pi", []string{"--continue"}, []string{"-ne", "--continue"}},
		{"pi", []string{"new", "--model", "own-model", "literal $(payload)"}, []string{"-ne", "--model", "own-model", "literal $(payload)"}},
	} {
		actual, err := programArguments(item.program, item.input)
		if err != nil || !reflect.DeepEqual(actual, item.expected) {
			t.Errorf("%s %q: got %q, %v; want %q", item.program, item.input, actual, err, item.expected)
		}
	}
}

func TestNativeClientReceivesTerminalInputAndOwnEnvironment(t *testing.T) {
	a, bin, shell := launcherFixture(t)
	launcherScript(t, bin, "codex", shell, `
IFS= read -r line
[ -z "${PI_PACKAGE_DIR-}" ] || exit 21
[ "$#" -eq 0 ] || exit 22
printf 'native client read: %s\n' "$line"
`)
	if err := a.saveConfig(config{Program: "codex"}); err != nil {
		t.Fatal(err)
	}
	command := exec.Command(os.Args[0], "-test.run=^TestLauncherExecHelper$")
	command.Env = append(os.Environ(), "ORGM_LAUNCHER_TEST=1", "PI_PACKAGE_DIR=unrelated-agent")
	command.Stdin = strings.NewReader("caller input\n")
	output, err := command.CombinedOutput()
	if err != nil || string(output) != "native client read: caller input\n" {
		t.Fatalf("native terminal launch: %q, %v", output, err)
	}
}

func TestLauncherExecHelper(t *testing.T) {
	if os.Getenv("ORGM_LAUNCHER_TEST") != "1" {
		return
	}
	a, err := newApp()
	if err != nil {
		t.Fatal(err)
	}
	if err := a.run([]string{"new"}); err != nil {
		t.Fatal(err)
	}
}

func isolatedNativeRuntime(t *testing.T) string {
	t.Helper()
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("PATH", filepath.Join(home, "empty-path"))
	t.Setenv("XDG_DATA_HOME", filepath.Join(home, "data"))
	t.Setenv("BUN_INSTALL", "")
	t.Setenv("NPM_CONFIG_PREFIX", "")
	t.Setenv("FNM_DIR", "")
	return home
}
