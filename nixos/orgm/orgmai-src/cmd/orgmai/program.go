package main

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
)

type chatProgram struct {
	id, label, install string
}

var chatPrograms = []chatProgram{
	{"claude", "Claude", "claude-install"},
	{"codex", "Codex", "codex-install"},
	{"opencode", "OpenCode", "instala OpenCode en ~/.opencode/bin o añádelo a PATH"},
	{"omp", "OMP", "omp-install"},
	{"pi", "Pi", "pi-install"},
}

func (a *app) chooseProgram(force bool) (config, bool, error) {
	cfg, err := a.loadConfig()
	if err != nil {
		return cfg, false, err
	}
	if cfg.Program != "" && !force {
		for _, program := range chatPrograms {
			if cfg.Program == program.id {
				return cfg, false, nil
			}
		}
		return cfg, false, fmt.Errorf("programa de AI Chat desconocido %q; ejecuta ai-chat program", cfg.Program)
	}
	header := "¿Con qué programa quieres abrir AI Chat?"
	for {
		choices := make([]string, 0, len(chatPrograms))
		byLabel := make(map[string]chatProgram)
		for _, program := range chatPrograms {
			label := program.label
			if _, err := findProgram(program.id); err != nil {
				label += " (no instalado)"
			}
			if program.id == cfg.Program {
				label += " (actual)"
			}
			choices = append(choices, label)
			byLabel[label] = program
		}
		selected, cancelled, err := gumChoose(header, choices)
		if err != nil || cancelled {
			return cfg, cancelled, err
		}
		program, ok := byLabel[selected]
		if !ok {
			return cfg, false, errors.New("el selector devolvió un programa desconocido")
		}
		if _, err := findProgram(program.id); err != nil {
			header = fmt.Sprintf("%s no está instalado: %s. Elige otro o pulsa Esc.", program.label, program.install)
			continue
		}
		cfg.Program = program.id
		if err := a.saveConfig(cfg); err != nil {
			return cfg, false, err
		}
		return cfg, false, nil
	}
}

func findProgram(name string) (string, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	data := os.Getenv("XDG_DATA_HOME")
	if data == "" {
		data = filepath.Join(home, ".local", "share")
	}
	fnm := os.Getenv("FNM_DIR")
	if fnm == "" {
		fnm = filepath.Join(data, "fnm")
	}
	bun := os.Getenv("BUN_INSTALL")
	if bun == "" {
		bun = filepath.Join(home, ".bun")
	}
	npm := os.Getenv("NPM_CONFIG_PREFIX")
	if npm == "" {
		npm = filepath.Join(home, ".npm-global")
	}
	directories := append(filepath.SplitList(os.Getenv("PATH")),
		filepath.Join(home, ".local", "bin"), filepath.Join(bun, "bin"),
		filepath.Join(npm, "bin"), filepath.Join(home, ".opencode", "bin"),
		filepath.Join(home, ".local", "share", "pnpm"), filepath.Join(fnm, "aliases", "default", "bin"))
	for _, directory := range directories {
		if !filepath.IsAbs(directory) {
			continue
		}
		path, err := exec.LookPath(filepath.Join(directory, name))
		if err != nil {
			continue
		}
		if personalShortcut(path, name) {
			continue
		}
		// Our shell shortcuts are not installations. Skip them when locating
		// the client so an orphan wrapper cannot pass the availability check.
		resolved, err := filepath.EvalSymlinks(path)
		if err == nil && strings.HasPrefix(resolved, "/nix/store/") &&
			strings.Contains(resolved, "-user-dotfiles/") &&
			strings.HasSuffix(resolved, "/programs/ai/.local/bin/"+name) {
			continue
		}
		return path, nil
	}
	for _, program := range chatPrograms {
		if program.id == name {
			return "", fmt.Errorf("%s no está instalado; %s. Para cambiar: ai-chat program", program.label, program.install)
		}
	}
	return "", fmt.Errorf("programa desconocido: %s", name)
}

func programArguments(program string, args []string) ([]string, error) {
	mode := "chat"
	if len(args) > 0 && (args[0] == "chat" || args[0] == "new" || args[0] == "prev") {
		mode, args = args[0], args[1:]
	}
	var result []string
	if program == "pi" {
		result = []string{"-ne"}
	}
	if mode == "prev" {
		switch program {
		case "codex":
			result = append(result, "resume")
		case "claude", "omp", "pi":
			result = append(result, "--resume")
		case "opencode":
			result = append(result, "--continue")
		}
	}
	return append(result, args...), nil
}

func (a *app) launchProgram(program string, args []string) error {
	path, err := findProgram(program)
	if err != nil {
		return err
	}
	argv, err := programArguments(program, args)
	if err != nil {
		return err
	}
	env := programEnvironment(program, path)
	return syscall.Exec(path, append([]string{path}, argv...), env)
}

func programEnvironment(program, path string) []string {
	env := make([]string, 0, len(os.Environ())+1)
	for _, value := range os.Environ() {
		if !strings.HasPrefix(value, "PATH=") && !strings.HasPrefix(value, "PI_PACKAGE_DIR=") {
			env = append(env, value)
		}
	}
	// execve does not remove duplicate environment keys. Keep exactly one PATH,
	// including the native JS client's own Node directory at a desktop launch.
	env = append(env, "PATH="+filepath.Dir(path)+string(os.PathListSeparator)+os.Getenv("PATH"))
	if program == "omp" {
		if resolved, err := filepath.EvalSymlinks(path); err == nil {
			root := filepath.Dir(filepath.Dir(resolved))
			if info, err := os.Stat(filepath.Join(root, "package.json")); err == nil && info.Mode().IsRegular() {
				env = append(env, "PI_PACKAGE_DIR="+root)
			}
		}
	}
	return env
}

// Copied personal shell shortcuts need another installation behind them. They
// must not count as an installed client or add their flags to the native launch.
func personalShortcut(path, name string) bool {
	if name != "claude" && name != "codex" {
		return false
	}
	f, err := os.Open(path)
	if err != nil {
		return false
	}
	defer f.Close()
	var head [4096]byte
	n, _ := f.Read(head[:])
	text := string(head[:n])
	return strings.Contains(text, "Skip this wrapper and execute the next Claude binary on PATH.") ||
		strings.Contains(text, "Keep stdin attached to the caller; enumerate executables on a separate FD.")
}
