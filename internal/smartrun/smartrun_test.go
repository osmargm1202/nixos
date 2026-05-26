package smartrun

import "testing"

func TestParsePlansDirectURLAndLocalhost(t *testing.T) {
	tests := []struct {
		name  string
		input string
		want  Plan
	}{
		{
			name:  "https url",
			input: "  https://example.com/path  ",
			want:  Plan{Kind: KindBrowserURL, URL: "https://example.com/path"},
		},
		{
			name:  "localhost adds http scheme",
			input: "localhost:8080",
			want:  Plan{Kind: KindBrowserURL, URL: "http://localhost:8080"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := Parse(tt.input, func(string) bool { return false })
			if got != tt.want {
				t.Fatalf("Parse(%q) = %#v, want %#v", tt.input, got, tt.want)
			}
		})
	}
}

func TestParsePlansHintsAndDefaultChatGPT(t *testing.T) {
	tests := []struct {
		name  string
		input string
		want  Plan
	}{
		{
			name:  "google hint strips marker and encodes spaces with plus",
			input: "!g hyprland lua",
			want:  Plan{Kind: KindBrowserURL, URL: "https://www.google.com/search?q=hyprland+lua"},
		},
		{
			name:  "youtube hint strips marker",
			input: "music !y lo fi",
			want:  Plan{Kind: KindBrowserURL, URL: "https://www.youtube.com/results?search_query=music++lo+fi"},
		},
		{
			name:  "claude hint launches desktop and copies stripped query",
			input: "summarize this !c",
			want:  Plan{Kind: KindDesktop, Desktop: "Claude.desktop", Query: "summarize this"},
		},
		{
			name:  "default query launches chatgpt desktop",
			input: "write test plan",
			want:  Plan{Kind: KindDesktop, Desktop: "Chatgpt.desktop", Query: "write test plan"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := Parse(tt.input, func(string) bool { return false })
			if got != tt.want {
				t.Fatalf("Parse(%q) = %#v, want %#v", tt.input, got, tt.want)
			}
		})
	}
}

func TestExecutionPlanBuildsBrowserDesktopAndCommandActions(t *testing.T) {
	tests := []struct {
		name string
		plan Plan
		want ExecutionPlan
	}{
		{
			name: "browser URL uses configured browser",
			plan: Plan{Kind: KindBrowserURL, URL: "https://example.com"},
			want: ExecutionPlan{Commands: []Command{{Name: "firefox", Args: []string{"https://example.com"}}}, Background: true},
		},
		{
			name: "desktop copies query then uses gio launcher",
			plan: Plan{Kind: KindDesktop, Desktop: "Claude.desktop", Query: "hello"},
			want: ExecutionPlan{Commands: []Command{{Name: "wl-copy", Stdin: "hello"}, {Name: "gio", Args: []string{"launch", "/home/me/.local/share/applications/Claude.desktop"}}}, Background: true},
		},
		{
			name: "command runs executable directly",
			plan: Plan{Kind: KindCommand, Command: "kitty"},
			want: ExecutionPlan{Commands: []Command{{Name: "kitty"}}, Background: true},
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := BuildExecutionPlan(tt.plan, Env{Browser: "firefox", Home: "/home/me", HasWLCopy: true, HasGIO: true})
			if !executionPlansEqual(got, tt.want) {
				t.Fatalf("BuildExecutionPlan() = %#v, want %#v", got, tt.want)
			}
		})
	}
}

func TestParsePlansCommandDomainAndEmptyInput(t *testing.T) {
	tests := []struct {
		name          string
		input         string
		commandExists func(string) bool
		want          Plan
	}{
		{
			name:          "single word executable launches command",
			input:         "kitty",
			commandExists: func(name string) bool { return name == "kitty" },
			want:          Plan{Kind: KindCommand, Command: "kitty"},
		},
		{
			name:          "domain gets https scheme",
			input:         "example.org/docs",
			commandExists: func(string) bool { return false },
			want:          Plan{Kind: KindBrowserURL, URL: "https://example.org/docs"},
		},
		{
			name:          "empty input is no-op",
			input:         "   ",
			commandExists: func(string) bool { return true },
			want:          Plan{Kind: KindNoop},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := Parse(tt.input, tt.commandExists)
			if got != tt.want {
				t.Fatalf("Parse(%q) = %#v, want %#v", tt.input, got, tt.want)
			}
		})
	}
}

func executionPlansEqual(a, b ExecutionPlan) bool {
	if a.Background != b.Background || len(a.Commands) != len(b.Commands) {
		return false
	}
	for i := range a.Commands {
		if a.Commands[i].Name != b.Commands[i].Name || a.Commands[i].Stdin != b.Commands[i].Stdin || len(a.Commands[i].Args) != len(b.Commands[i].Args) {
			return false
		}
		for j := range a.Commands[i].Args {
			if a.Commands[i].Args[j] != b.Commands[i].Args[j] {
				return false
			}
		}
	}
	return true
}
