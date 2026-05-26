package main

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestRunWithIOFinalExceptionSessionLockPrintsSafePlan(t *testing.T) {
	var stdout, stderr bytes.Buffer
	err := runWithIO([]string{"session", "lock", "--print"}, &stdout, &stderr)
	if err != nil {
		t.Fatalf("runWithIO(session lock --print) error = %v", err)
	}
	if got, want := stdout.String(), "hyprlock --immediate-render --no-fade-in\n"; got != want {
		t.Fatalf("stdout = %q, want %q", got, want)
	}
}

func TestRunWithIOFinalExceptionLauncherAppsPrintsHyprFuzzelPlan(t *testing.T) {
	t.Setenv("HYPR_FUZZEL_ENV", filepath.Join(t.TempDir(), "missing.env"))
	var stdout, stderr bytes.Buffer
	err := runWithIO([]string{"launcher", "apps", "--print", "--height", "2160", "--scale", "2"}, &stdout, &stderr)
	if err != nil {
		t.Fatalf("runWithIO(launcher apps --print) error = %v", err)
	}
	got := stdout.String()
	for _, want := range []string{"fuzzel", "--font=JetBrainsMono Nerd Font:size=12", "--width=34", "--lines=10", "--line-height=22"} {
		if !strings.Contains(got, want) {
			t.Fatalf("stdout = %q, want substring %q", got, want)
		}
	}
}

func TestRunWithIOFinalExceptionNotifyFocusAppPrintsPidPlan(t *testing.T) {
	var stdout, stderr bytes.Buffer
	err := runWithIO([]string{"notify", "focus-app", "--print", "--pid", "123"}, &stdout, &stderr)
	if err != nil {
		t.Fatalf("runWithIO(notify focus-app --print --pid) error = %v", err)
	}
	if got, want := stdout.String(), "focus-pid=123\n"; got != want {
		t.Fatalf("stdout = %q, want %q", got, want)
	}
}

func TestRunWithIOFinalExceptionFileOpenPrintPlans(t *testing.T) {
	home := t.TempDir()
	file := filepath.Join(home, "notes", "todo.txt")
	if err := os.MkdirAll(filepath.Dir(file), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(file, []byte("x"), 0o600); err != nil {
		t.Fatal(err)
	}
	var stdout, stderr bytes.Buffer
	err := runWithIO([]string{"file", "open-terminal", "--print", "--home", home, "--select", "notes/todo.txt"}, &stdout, &stderr)
	if err != nil {
		t.Fatalf("runWithIO(file open-terminal --print) error = %v", err)
	}
	if got, want := stdout.String(), "kitty --directory "+filepath.Dir(file)+"\n"; got != want {
		t.Fatalf("stdout = %q, want %q", got, want)
	}
}

func TestRunWithIOFinalExceptionSSHHostPrintPlan(t *testing.T) {
	home := t.TempDir()
	sshDir := filepath.Join(home, ".ssh")
	if err := os.MkdirAll(sshDir, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(sshDir, "config"), []byte("Host prod *.wild\n  HostName example\nHost lab\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	var stdout, stderr bytes.Buffer
	err := runWithIO([]string{"ssh", "host", "--print", "--home", home, "--select", "lab"}, &stdout, &stderr)
	if err != nil {
		t.Fatalf("runWithIO(ssh host --print) error = %v", err)
	}
	if got, want := stdout.String(), "kitty -e ssh lab\n"; got != want {
		t.Fatalf("stdout = %q, want %q", got, want)
	}
}

func TestRunWithIOFinalExceptionTmuxArchPrintPlan(t *testing.T) {
	var stdout, stderr bytes.Buffer
	err := runWithIO([]string{"tmux", "arch", "--print", "--select", "work: 1 windows"}, &stdout, &stderr)
	if err != nil {
		t.Fatalf("runWithIO(tmux arch --print) error = %v", err)
	}
	if got, want := stdout.String(), "kitty -e distrobox-enter arch -- tmux attach -t work\n"; got != want {
		t.Fatalf("stdout = %q, want %q", got, want)
	}
}

func TestRunWithIOFinalExceptionCalcFuzzelPrintPlan(t *testing.T) {
	var stdout, stderr bytes.Buffer
	err := runWithIO([]string{"calc", "fuzzel", "--print", "--expr", "1+2"}, &stdout, &stderr)
	if err != nil {
		t.Fatalf("runWithIO(calc fuzzel --print) error = %v", err)
	}
	if got := stdout.String(); !strings.Contains(got, "qalc -t 1+2") || !strings.Contains(got, "wl-copy") {
		t.Fatalf("stdout = %q, want qalc and wl-copy plan", got)
	}
}

func TestRunWithIOFinalExceptionPiPromptPrintPlan(t *testing.T) {
	var stdout, stderr bytes.Buffer
	err := runWithIO([]string{"pi", "prompt", "--launcher", "walker", "--print", "--input", "hola"}, &stdout, &stderr)
	if err != nil {
		t.Fatalf("runWithIO(pi prompt --print) error = %v", err)
	}
	if got, want := stdout.String(), "kitty --class kitty --hold -e distrobox-enter arch -- pi hola\n"; got != want {
		t.Fatalf("stdout = %q, want %q", got, want)
	}
}

func TestRunWithIOFinalExceptionWebappInteractiveCancellationIsSafe(t *testing.T) {
	var stdout, stderr bytes.Buffer
	err := runWithIO([]string{"webapp", "create", "--interactive", "--cancel"}, &stdout, &stderr)
	if err != nil {
		t.Fatalf("runWithIO(webapp create --interactive --cancel) error = %v", err)
	}
	if got, want := stdout.String(), "cancelled\n"; got != want {
		t.Fatalf("stdout = %q, want %q", got, want)
	}
}
