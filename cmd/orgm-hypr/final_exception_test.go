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

func TestRunWithIOFinalExceptionNotifyFocusAppOnlyPrintsAllowedMatches(t *testing.T) {
	tests := []struct {
		name  string
		match string
		want  string
	}{
		{name: "pi question", match: "Pi Question", want: "focus-match=pi[-_.]*question\n"},
		{name: "dota", match: "Dota 2", want: "focus-match=dota[-_.]*2\n"},
		{name: "unlisted", match: "Slack", want: "focus-disabled=slack\n"},
		{name: "partial pi", match: "Pi", want: "focus-disabled=pi\n"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var stdout, stderr bytes.Buffer
			err := runWithIO([]string{"notify", "focus-app", "--print", "--match", tt.match}, &stdout, &stderr)
			if err != nil {
				t.Fatalf("runWithIO(notify focus-app --print --match) error = %v", err)
			}
			if got := stdout.String(); got != tt.want {
				t.Fatalf("stdout = %q, want %q", got, tt.want)
			}
		})
	}
}

func TestRunWithIOFinalExceptionNotifyFocusAppLoadsAllowlistConfig(t *testing.T) {
	config := filepath.Join(t.TempDir(), "notify-focus.json")
	if err := os.WriteFile(config, []byte(`{"allow":[{"match":"Slack"}]}`), 0o600); err != nil {
		t.Fatal(err)
	}
	var stdout, stderr bytes.Buffer
	err := runWithIO([]string{"notify", "focus-app", "--print", "--config", config, "--match", "Slack"}, &stdout, &stderr)
	if err != nil {
		t.Fatalf("runWithIO(notify focus-app --print --config --match) error = %v", err)
	}
	if got, want := stdout.String(), "focus-match=slack\n"; got != want {
		t.Fatalf("stdout = %q, want %q", got, want)
	}
}

func TestEvaluateBatteryAlertSendsEachThresholdOnceAndResets(t *testing.T) {
	state := batteryAlertState{}
	decision, next := evaluateBatteryAlert(batterySnapshot{Capacity: 50, Status: "Discharging"}, state)
	assertBatteryAlert(t, decision, "normal", "Batería al 50%", "󰁾 50%")

	decision, next = evaluateBatteryAlert(batterySnapshot{Capacity: 49, Status: "Discharging"}, next)
	if decision.Notify != nil {
		t.Fatalf("49%% repeated notify = %#v, want nil", decision.Notify)
	}

	decision, next = evaluateBatteryAlert(batterySnapshot{Capacity: 20, Status: "Discharging"}, next)
	assertBatteryAlert(t, decision, "normal", "Batería baja", "󰁻 20%")

	decision, next = evaluateBatteryAlert(batterySnapshot{Capacity: 10, Status: "Discharging"}, next)
	assertBatteryAlert(t, decision, "critical", "✖ BATERÍA CRÍTICA", "🔴 󰂃 10%")

	decision, next = evaluateBatteryAlert(batterySnapshot{Capacity: 21, Status: "Charging"}, next)
	if decision.Notify != nil {
		t.Fatalf("charging notify = %#v, want nil", decision.Notify)
	}

	decision, _ = evaluateBatteryAlert(batterySnapshot{Capacity: 20, Status: "Discharging"}, next)
	assertBatteryAlert(t, decision, "normal", "Batería baja", "󰁻 20%")
}

func assertBatteryAlert(t *testing.T, decision batteryAlertDecision, urgency, summary, body string) {
	t.Helper()
	if decision.Notify == nil {
		t.Fatalf("Notify = nil, want %q", summary)
	}
	if decision.Notify.Urgency != urgency || decision.Notify.Summary != summary || decision.Notify.Body != body {
		t.Fatalf("Notify = %#v, want urgency=%q summary=%q body=%q", decision.Notify, urgency, summary, body)
	}
}

func TestRunWithIOFinalExceptionNotifyBatteryDaemonPrintsCriticalAlert(t *testing.T) {
	statePath := filepath.Join(t.TempDir(), "battery-alerts.json")
	var stdout, stderr bytes.Buffer
	err := runWithIO([]string{"notify", "battery-daemon", "--once", "--print", "--capacity", "10", "--status", "Discharging", "--state", statePath}, &stdout, &stderr)
	if err != nil {
		t.Fatalf("runWithIO(notify battery-daemon --once --print) error = %v", err)
	}
	got := stdout.String()
	for _, want := range []string{"notify-send", "-a orgm-hypr-battery", "-u critical", "x-canonical-private-synchronous:orgm-hypr-battery", "✖ BATERÍA CRÍTICA", "🔴 󰂃 10%"} {
		if !strings.Contains(got, want) {
			t.Fatalf("stdout = %q, want substring %q", got, want)
		}
	}
}

func TestRunWithIOFinalExceptionNotifyBatteryDaemonSkipsWhenCharging(t *testing.T) {
	statePath := filepath.Join(t.TempDir(), "battery-alerts.json")
	var stdout, stderr bytes.Buffer
	err := runWithIO([]string{"notify", "battery-daemon", "--once", "--print", "--capacity", "10", "--status", "Charging", "--state", statePath}, &stdout, &stderr)
	if err != nil {
		t.Fatalf("runWithIO(notify battery-daemon charging) error = %v", err)
	}
	if got := stdout.String(); got != "" {
		t.Fatalf("stdout = %q, want empty", got)
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

	stdout.Reset()
	stderr.Reset()
	err = runWithIO([]string{"file", "open-dir", "--print", "--home", home, "--select", "notes/todo.txt"}, &stdout, &stderr)
	if err != nil {
		t.Fatalf("runWithIO(file open-dir --print) error = %v", err)
	}
	if got, want := stdout.String(), "nautilus --new-window "+filepath.Dir(file)+"\n"; got != want {
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
