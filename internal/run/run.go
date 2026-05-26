package run

import (
	"bytes"
	"context"
	"os/exec"
)

// CommandOutput runs a command and returns trimmed stdout/stderr separately.
// It is intentionally small for early orgm-hypr migration helpers.
func CommandOutput(ctx context.Context, name string, args ...string) (string, string, error) {
	cmd := exec.CommandContext(ctx, name, args...)
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	err := cmd.Run()
	return stdout.String(), stderr.String(), err
}
