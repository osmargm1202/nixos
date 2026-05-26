package smartrun

import (
	"path/filepath"
	"regexp"
	"strings"
)

// Kind describes the side effect the compatibility script would perform.
type Kind string

const (
	KindNoop       Kind = "noop"
	KindBrowserURL Kind = "browser-url"
	KindDesktop    Kind = "desktop"
	KindCommand    Kind = "command"
)

// Plan is the parsed smart-run action without executing GUI/browser commands.
type Plan struct {
	Kind    Kind
	URL     string
	Desktop string
	Query   string
	Command string
}

type Command struct {
	Name  string
	Args  []string
	Stdin string
}

type ExecutionPlan struct {
	Commands   []Command
	Background bool
}

type Env struct {
	Browser   string
	Home      string
	HasWLCopy bool
	HasGIO    bool
}

var domainPattern = regexp.MustCompile(`^[A-Za-z0-9.-]+\.[A-Za-z]{2,}(/.*)?$`)

// Parse mirrors hypr-smart-run input classification while avoiding side effects.
func Parse(input string, commandExists func(string) bool) Plan {
	trimmed := strings.TrimSpace(input)
	if trimmed == "" {
		return Plan{Kind: KindNoop}
	}
	if strings.HasPrefix(trimmed, "http://") || strings.HasPrefix(trimmed, "https://") {
		return Plan{Kind: KindBrowserURL, URL: trimmed}
	}
	if strings.HasPrefix(trimmed, "localhost:") || strings.HasPrefix(trimmed, "127.0.0.1:") {
		return Plan{Kind: KindBrowserURL, URL: "http://" + trimmed}
	}
	if strings.Contains(trimmed, "!a") {
		return Plan{Kind: KindDesktop, Desktop: "Chatgpt.desktop", Query: stripHint(trimmed, "!a")}
	}
	if strings.Contains(trimmed, "!c") {
		return Plan{Kind: KindDesktop, Desktop: "Claude.desktop", Query: stripHint(trimmed, "!c")}
	}
	if strings.Contains(trimmed, "!g") {
		return Plan{Kind: KindBrowserURL, URL: "https://www.google.com/search?q=" + plusQuery(stripHint(trimmed, "!g"))}
	}
	if strings.Contains(trimmed, "!y") {
		return Plan{Kind: KindBrowserURL, URL: "https://www.youtube.com/results?search_query=" + plusQuery(stripHint(trimmed, "!y"))}
	}
	if !strings.Contains(trimmed, " ") && commandExists != nil && commandExists(trimmed) {
		return Plan{Kind: KindCommand, Command: trimmed}
	}
	if !strings.Contains(trimmed, " ") && domainPattern.MatchString(trimmed) {
		return Plan{Kind: KindBrowserURL, URL: "https://" + trimmed}
	}
	return Plan{Kind: KindDesktop, Desktop: "Chatgpt.desktop", Query: trimmed}
}

func stripHint(input, hint string) string {
	return strings.TrimSpace(strings.ReplaceAll(input, hint, ""))
}

func plusQuery(input string) string {
	return strings.ReplaceAll(input, " ", "+")
}

func BuildExecutionPlan(plan Plan, env Env) ExecutionPlan {
	browser := env.Browser
	if browser == "" {
		browser = "chromium"
	}
	switch plan.Kind {
	case KindBrowserURL:
		return ExecutionPlan{Commands: []Command{{Name: browser, Args: []string{plan.URL}}}, Background: true}
	case KindDesktop:
		commands := []Command{}
		if plan.Query != "" && env.HasWLCopy {
			commands = append(commands, Command{Name: "wl-copy", Stdin: plan.Query})
		}
		desktopPath := filepath.Join(env.Home, ".local", "share", "applications", plan.Desktop)
		if env.HasGIO {
			commands = append(commands, Command{Name: "gio", Args: []string{"launch", desktopPath}})
		} else {
			commands = append(commands, Command{Name: "gtk-launch", Args: []string{strings.TrimSuffix(plan.Desktop, ".desktop")}})
		}
		return ExecutionPlan{Commands: commands, Background: true}
	case KindCommand:
		return ExecutionPlan{Commands: []Command{{Name: plan.Command}}, Background: true}
	default:
		return ExecutionPlan{}
	}
}
