package dotadd

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/osmargm1202/nixos/internal/dotconfig"
)

func TestNormalizeTargetRelativePathUsesWorkingDirectory(t *testing.T) {
	home := t.TempDir()
	cwd := filepath.Join(home, ".config", "pi")
	if err := os.MkdirAll(cwd, 0o755); err != nil {
		t.Fatal(err)
	}
	oldwd, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.Chdir(oldwd) })
	if err := os.Chdir(cwd); err != nil {
		t.Fatal(err)
	}

	rel, err := NormalizeTarget(dotconfig.Runtime{Home: home, Destination: home}, "ask.jsonc")
	if err != nil {
		t.Fatal(err)
	}
	if rel != ".config/pi/ask.jsonc" {
		t.Fatalf("relative target = %q, want .config/pi/ask.jsonc", rel)
	}
}
