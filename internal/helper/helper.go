package helper

import (
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/osmargm1202/nixos/internal/cli"
	"github.com/osmargm1202/nixos/internal/menu"
)

type Cache struct {
	SchemaVersion   int                  `json:"schemaVersion"`
	GeneratedAt     string               `json:"generatedAt"`
	DefaultCategory string               `json:"defaultCategory"`
	Categories      []KeybindingCategory `json:"categories"`
}

type KeybindingCategory struct {
	ID      string            `json:"id"`
	Title   string            `json:"title"`
	Icon    string            `json:"icon,omitempty"`
	Entries []KeybindingEntry `json:"entries"`
}

type KeybindingEntry struct {
	Key         string `json:"key"`
	Description string `json:"description"`
	Command     string `json:"command,omitempty"`
}

type Request struct {
	Action      string `json:"action"`
	RequestedAt string `json:"requestedAt"`
	CachePath   string `json:"cachePath"`
}

func Run(args []string, stdout, stderr io.Writer) error {
	if len(args) < 1 {
		return cli.UsageError("usage: orgm-hypr helper [init|toggle]")
	}
	flags := flag.NewFlagSet("orgm-hypr helper "+args[0], flag.ContinueOnError)
	flags.SetOutput(stderr)
	stateHome := flags.String("state-home", defaultStateHome(), "XDG state home")
	printOnly := flags.Bool("print", false, "print launch command instead of executing")
	if err := flags.Parse(args[1:]); err != nil {
		return cli.UsageError(err.Error())
	}
	if flags.NArg() != 0 {
		return cli.UsageError("unexpected argument: %s", flags.Arg(0))
	}
	switch args[0] {
	case "init":
		path, err := Init(*stateHome)
		if err != nil {
			return err
		}
		fmt.Fprintf(stdout, "wrote %s\n", path)
		return nil
	case "toggle":
		return Toggle(*stateHome, *printOnly, stdout)
	default:
		return cli.UsageError("usage: orgm-hypr helper [init|toggle]")
	}
}

func BuildCache() Cache {
	cats := menu.KeybindingCategories()
	out := make([]KeybindingCategory, 0, len(cats))
	for _, cat := range cats {
		entries := make([]KeybindingEntry, 0, len(cat.Entries))
		for _, entry := range cat.Entries {
			entries = append(entries, KeybindingEntry{Key: entry.Key, Description: entry.Description, Command: entry.Command})
		}
		out = append(out, KeybindingCategory{ID: cat.ID, Title: cat.Title, Icon: cat.Icon, Entries: entries})
	}
	return Cache{SchemaVersion: 1, GeneratedAt: time.Now().UTC().Format(time.RFC3339), DefaultCategory: "launchers", Categories: out}
}

func Init(stateHome string) (string, error) {
	path := cachePath(stateHome)
	return path, atomicWriteJSON(path, BuildCache())
}

func Toggle(stateHome string, printOnly bool, stdout io.Writer) error {
	cache := cachePath(stateHome)
	if _, err := os.Stat(cache); err != nil {
		if !os.IsNotExist(err) {
			return err
		}
		if _, err := Init(stateHome); err != nil {
			return err
		}
	}
	requestPath := filepath.Join(helperDir(stateHome), "keyhelper-request.json")
	request := Request{Action: "toggle", RequestedAt: time.Now().UTC().Format(time.RFC3339Nano), CachePath: cache}
	if err := atomicWriteJSON(requestPath, request); err != nil {
		return err
	}
	cmd := []string{"quickshell", "-c", keyhelperShellPath()}
	if printOnly {
		fmt.Fprintln(stdout, shellJoin(cmd))
		return nil
	}
	if isKeyhelperRunning() {
		return nil
	}
	if _, err := exec.LookPath("quickshell"); err != nil {
		return fmt.Errorf("quickshell not found: %w", err)
	}
	return exec.Command(cmd[0], cmd[1:]...).Start()
}

func defaultStateHome() string {
	if v := os.Getenv("XDG_STATE_HOME"); v != "" {
		return v
	}
	return filepath.Join(os.Getenv("HOME"), ".local", "state")
}

func keyhelperShellPath() string {
	configHome := os.Getenv("XDG_CONFIG_HOME")
	if configHome == "" {
		configHome = filepath.Join(os.Getenv("HOME"), ".config")
	}
	return filepath.Join(configHome, "quickshell", "modules", "keyhelper", "shell.qml")
}
func helperDir(stateHome string) string { return filepath.Join(stateHome, "orgm-helper") }
func cachePath(stateHome string) string {
	return filepath.Join(helperDir(stateHome), "keybindings.json")
}

func atomicWriteJSON(path string, payload any) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	data, err := json.MarshalIndent(payload, "", "  ")
	if err != nil {
		return err
	}
	tmp, err := os.CreateTemp(filepath.Dir(path), "."+filepath.Base(path)+".")
	if err != nil {
		return err
	}
	name := tmp.Name()
	defer os.Remove(name)
	if _, err := tmp.Write(append(data, '\n')); err != nil {
		_ = tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	return os.Rename(name, path)
}

func isKeyhelperRunning() bool {
	return exec.Command("pgrep", "-f", "quickshell .*keyhelper").Run() == nil
}

func shellJoin(args []string) string {
	out := ""
	for i, arg := range args {
		if i > 0 {
			out += " "
		}
		out += shellQuote(arg)
	}
	return out
}

func shellQuote(arg string) string {
	if arg == "" {
		return "''"
	}
	for _, r := range arg {
		if !((r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || (r >= '0' && r <= '9') || r == '_' || r == '-' || r == '.' || r == '/' || r == ':') {
			return "'" + strings.ReplaceAll(arg, "'", "'\\''") + "'"
		}
	}
	return arg
}
