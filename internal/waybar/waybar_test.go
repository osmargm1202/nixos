package waybar

import (
	"strings"
	"testing"
	"time"
)

func TestFormatDateHelpersMatchExistingScripts(t *testing.T) {
	tm := time.Date(2026, time.May, 22, 23, 54, 0, 0, time.UTC)

	tests := []struct {
		format string
		want   string
	}{
		{format: "date-es", want: "22/05/2026"},
		{format: "day-month-es", want: "Viernes - Mayo"},
		{format: "time-ampm", want: "11:54 PM"},
	}

	for _, tt := range tests {
		t.Run(tt.format, func(t *testing.T) {
			got, err := FormatDate(tm, tt.format)
			if err != nil {
				t.Fatalf("FormatDate(%q) error = %v", tt.format, err)
			}
			if got != tt.want {
				t.Fatalf("FormatDate(%q) = %q, want %q", tt.format, got, tt.want)
			}
		})
	}
}

func TestSwapUsageFromMeminfoRoundsLikeAwkScript(t *testing.T) {
	got, err := SwapUsageFromMeminfo(strings.NewReader("SwapTotal:       2048 kB\nSwapFree:        1024 kB\n"))
	if err != nil {
		t.Fatalf("SwapUsageFromMeminfo() error = %v", err)
	}
	if want := "󰓡 SWAP 50%"; got != want {
		t.Fatalf("SwapUsageFromMeminfo() = %q, want %q", got, want)
	}

	got, err = SwapUsageFromMeminfo(strings.NewReader("SwapTotal:          0 kB\nSwapFree:           0 kB\n"))
	if err != nil {
		t.Fatalf("SwapUsageFromMeminfo(zero) error = %v", err)
	}
	if want := "󰓡 SWAP 0%"; got != want {
		t.Fatalf("SwapUsageFromMeminfo(zero) = %q, want %q", got, want)
	}
}

func TestWorkspaceStatusJSONMatchesHelperClasses(t *testing.T) {
	got, err := WorkspaceStatusJSON(2, 2, 3)
	if err != nil {
		t.Fatalf("WorkspaceStatusJSON(active) error = %v", err)
	}
	want := `{"text":"2","tooltip":"Workspace 2 · 3 window(s)","class":["workspace","active"]}` + "\n"
	if got != want {
		t.Fatalf("WorkspaceStatusJSON(active) = %q, want %q", got, want)
	}

	got, err = WorkspaceStatusJSON(4, 2, 0)
	if err != nil {
		t.Fatalf("WorkspaceStatusJSON(empty) error = %v", err)
	}
	want = `{"text":"4","tooltip":"Workspace 4 · 0 window(s)","class":["workspace","empty"]}` + "\n"
	if got != want {
		t.Fatalf("WorkspaceStatusJSON(empty) = %q, want %q", got, want)
	}
}

func TestWatchPlanMatchesExistingScriptDefaults(t *testing.T) {
	plan := WatchPlan("/home/osmarg/.config/waybar-hypr", "/home/osmarg/.local/state")

	if plan.Profile != "waybar-hypr" {
		t.Fatalf("Profile = %q, want waybar-hypr", plan.Profile)
	}
	if plan.LogPath != "/home/osmarg/.local/state/waybar/waybar-hypr.log" {
		t.Fatalf("LogPath = %q", plan.LogPath)
	}
	wantArgs := []string{"-c", "/home/osmarg/.config/waybar-hypr/config", "-s", "/home/osmarg/.config/waybar-hypr/style.css"}
	if strings.Join(plan.WaybarArgs, "\x00") != strings.Join(wantArgs, "\x00") {
		t.Fatalf("WaybarArgs = %#v, want %#v", plan.WaybarArgs, wantArgs)
	}
}
