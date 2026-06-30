package cli

import (
	"errors"
	"fmt"
	"io"
)

// ExitError carries a process exit code for command-line failures.
type ExitError struct {
	Code int
	Err  error
}

func (e *ExitError) Error() string {
	if e == nil || e.Err == nil {
		return ""
	}
	return e.Err.Error()
}

func (e *ExitError) Unwrap() error {
	if e == nil {
		return nil
	}
	return e.Err
}

// UsageError creates a deterministic command usage failure.
func UsageError(format string, args ...any) *ExitError {
	return &ExitError{Code: 2, Err: fmt.Errorf(format, args...)}
}

// PrintError writes an error to stderr and returns its intended exit code.
func PrintError(stderr io.Writer, err error) int {
	if err == nil {
		return 0
	}
	fmt.Fprintln(stderr, err)
	var exitErr *ExitError
	if errors.As(err, &exitErr) && exitErr.Code != 0 {
		return exitErr.Code
	}
	return 1
}
