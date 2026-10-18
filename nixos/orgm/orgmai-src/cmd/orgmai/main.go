package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// Each client owns its models, credentials, interface and conversation history.
type config struct {
	Program string `json:"program,omitempty"`
}

type app struct {
	configPath string
}

func main() {
	application, err := newApp()
	if err == nil {
		err = application.run(os.Args[1:])
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, "orgmai:", err)
		os.Exit(1)
	}
}

func (a *app) run(args []string) error {
	if len(args) > 0 {
		switch args[0] {
		case "--help", "-h", "help":
			printHelp()
			return nil
		case "--version":
			fmt.Println("orgmai 0.4.0")
			return nil
		case "config", "program":
			_, _, err := a.chooseProgram(true)
			return err
		}
	}
	cfg, cancelled, err := a.chooseProgram(false)
	if err != nil || cancelled {
		return err
	}
	return a.launchProgram(cfg.Program, args)
}

func printHelp() {
	fmt.Print(`ai-chat / orgmai - lanzador de programas de IA

  orgmai [ARG...]       Ejecutar el programa elegido con sus argumentos
  orgmai new [ARG...]   Alias de lanzamiento normal (Super+A)
  orgmai chat [ARG...]  Alias de lanzamiento normal
  orgmai prev          Abrir el historial nativo (Super+Shift+A)
  orgmai program       Cambiar de programa (Super+Ctrl+Shift+A)
  orgmai config        Alias de program

Programas: Claude, Codex, OpenCode, OMP y Pi.
La primera ejecución pregunta qué programa usar y guarda solo esa elección en
$XDG_CONFIG_HOME/orgmai/config.json. Pi se ejecuta con -ne (sin extensiones).
Cada programa usa sus propios modelos, credenciales, interfaz e historial.
Los atajos del escritorio lo abren en una terminal Kitty flotante.
`)
}

func newApp() (*app, error) {
	configHome := os.Getenv("XDG_CONFIG_HOME")
	if configHome == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			return nil, fmt.Errorf("resolve home directory: %w", err)
		}
		configHome = filepath.Join(home, ".config")
	}
	return &app{configPath: filepath.Join(configHome, "orgmai", "config.json")}, nil
}

func (a *app) loadConfig() (config, error) {
	var cfg config
	data, err := os.ReadFile(a.configPath)
	if errors.Is(err, os.ErrNotExist) {
		return cfg, nil
	}
	if err != nil {
		return cfg, fmt.Errorf("read launcher configuration: %w", err)
	}
	// Legacy provider/model/thinking values are ignored, never forwarded.
	if err := json.Unmarshal(data, &cfg); err != nil {
		return cfg, fmt.Errorf("parse launcher configuration %s: %w", a.configPath, err)
	}
	return cfg, nil
}

func (a *app) saveConfig(cfg config) error {
	dir := filepath.Dir(a.configPath)
	if err := os.MkdirAll(dir, 0700); err != nil {
		return fmt.Errorf("create launcher configuration directory: %w", err)
	}
	data, err := json.MarshalIndent(cfg, "", "  ")
	if err != nil {
		return err
	}
	tmp, err := os.CreateTemp(dir, ".config-*.json")
	if err != nil {
		return err
	}
	defer os.Remove(tmp.Name())
	if _, err := tmp.Write(append(data, '\n')); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Sync(); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	return os.Rename(tmp.Name(), a.configPath)
}

func gumChoose(header string, choices []string) (string, bool, error) {
	cmd := exec.Command("gum", "choose", "--header", header)
	cmd.Stdin = strings.NewReader(strings.Join(choices, "\n") + "\n")
	cmd.Stderr = os.Stderr
	output, err := cmd.Output()
	if err != nil {
		var exit *exec.ExitError
		if errors.As(err, &exit) && exit.ExitCode() == 130 {
			return "", true, nil
		}
		return "", false, fmt.Errorf("run program picker: %w", err)
	}
	return strings.TrimSpace(string(output)), false, nil
}
