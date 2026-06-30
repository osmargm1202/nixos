package dotinstall

import (
	"fmt"
	"os"
	"path/filepath"
)

func Run(home, executable string) ([]string, error) {
	if executable == "" {
		var err error
		executable, err = os.Executable()
		if err != nil {
			return nil, err
		}
	}
	binDir := filepath.Join(home, ".local", "bin")
	if err := os.MkdirAll(binDir, 0o755); err != nil {
		return nil, err
	}
	dotLink := filepath.Join(binDir, "dot")
	_ = os.Remove(dotLink)
	if err := os.Symlink(executable, dotLink); err != nil {
		return nil, err
	}
	_ = os.Remove(filepath.Join(binDir, "dot.sh"))
	return []string{
		fmt.Sprintf("installed: %s -> %s", dotLink, executable),
		"launch example: orgm-dot daemon --host orgm",
	}, nil
}
