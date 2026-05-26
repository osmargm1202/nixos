package webapp

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
)

type CreateOptions struct{ DataHome, Name, URL, Browser string }
type CreatePlanData struct{ Slug, URL, Browser, DesktopPath, LauncherPath, IconPath, ProfilePath, Class, DesktopContent, LauncherContent string }
type App struct{ Name, URL, DesktopPath, Exec string }
type RemoveOptions struct {
	DataHome, DesktopPath string
	RemoveProfile         bool
	Confirm               string
}
type RemovePlanData struct{ RemovePaths []string }

func CreatePlan(opts CreateOptions) (CreatePlanData, error) {
	name := strings.TrimSpace(singleLine(opts.Name))
	if name == "" {
		return CreatePlanData{}, fmt.Errorf("name is required")
	}
	url := NormalizeURL(opts.URL)
	if url == "" {
		return CreatePlanData{}, fmt.Errorf("url is required")
	}
	browser := opts.Browser
	if browser == "" {
		browser = "chromium"
	}
	dataHome := opts.DataHome
	if dataHome == "" {
		dataHome = defaultDataHome()
	}
	slug := Slugify(name)
	if slug == "" {
		slug = "hypr-webapp"
	}
	state := filepath.Join(dataHome, "hypr", "webapps")
	plan := CreatePlanData{Slug: slug, URL: url, Browser: browser, DesktopPath: filepath.Join(dataHome, "applications", slug+".desktop"), LauncherPath: filepath.Join(state, "bin", "hypr-webapp-"+slug), IconPath: filepath.Join(dataHome, "icons", slug+".png"), ProfilePath: filepath.Join(state, "profiles", slug), Class: "chrome-" + regexp.MustCompile(`[^A-Za-z0-9]`).ReplaceAllString(domainOf(url), "-") + "__-Default"}
	plan.LauncherContent = launcherContent(plan)
	plan.DesktopContent = desktopContent(name, plan)
	return plan, nil
}

func Slugify(value string) string {
	s := strings.ToLower(value)
	s = regexp.MustCompile(`[^a-z0-9]+`).ReplaceAllString(s, "-")
	s = strings.Trim(s, "-")
	s = regexp.MustCompile(`-+`).ReplaceAllString(s, "-")
	return s
}

func NormalizeURL(value string) string {
	value = strings.TrimSpace(singleLine(value))
	if value == "" {
		return ""
	}
	if strings.HasPrefix(value, "http://") || strings.HasPrefix(value, "https://") {
		return value
	}
	return "https://" + value
}

func List(dataHome string) ([]App, error) {
	appsDir := filepath.Join(dataHomeOrDefault(dataHome), "applications")
	entries, err := os.ReadDir(appsDir)
	if os.IsNotExist(err) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	var apps []App
	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".desktop") {
			continue
		}
		path := filepath.Join(appsDir, entry.Name())
		fields, err := readDesktop(path)
		if err != nil || fields["X-Hypr-WebApp"] != "true" {
			continue
		}
		name := fields["Name"]
		if name == "" {
			name = entry.Name()
		}
		apps = append(apps, App{Name: name, URL: fields["X-Hypr-WebApp-URL"], DesktopPath: path, Exec: fields["Exec"]})
	}
	sort.Slice(apps, func(i, j int) bool { return apps[i].Name < apps[j].Name })
	return apps, nil
}

func RemovePlan(opts RemoveOptions) (RemovePlanData, error) {
	if opts.DesktopPath == "" {
		return RemovePlanData{}, fmt.Errorf("desktop path is required")
	}
	fields, err := readDesktop(opts.DesktopPath)
	if err != nil {
		return RemovePlanData{}, err
	}
	if fields["X-Hypr-WebApp"] != "true" {
		return RemovePlanData{}, fmt.Errorf("not a Hypr webapp desktop file")
	}
	dataHome := dataHomeOrDefault(opts.DataHome)
	slug := strings.TrimSuffix(filepath.Base(opts.DesktopPath), ".desktop")
	slug = strings.TrimPrefix(slug, "hypr-webapp-")
	safeLauncher := filepath.Join(dataHome, "hypr", "webapps", "bin", "hypr-webapp-"+slug)
	paths := []string{opts.DesktopPath}
	if fields["Exec"] == safeLauncher {
		paths = append(paths, safeLauncher)
	}
	if opts.RemoveProfile {
		if opts.Confirm != "delete-profile" {
			return RemovePlanData{}, fmt.Errorf("profile removal requires --confirm delete-profile")
		}
		paths = append(paths, filepath.Join(dataHome, "hypr", "webapps", "profiles", slug))
	}
	return RemovePlanData{RemovePaths: paths}, nil
}

func readDesktop(path string) (map[string]string, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	out := map[string]string{}
	for _, line := range strings.Split(string(data), "\n") {
		key, val, ok := strings.Cut(line, "=")
		if ok {
			out[key] = val
		}
	}
	return out, nil
}
func dataHomeOrDefault(v string) string {
	if v != "" {
		return v
	}
	return defaultDataHome()
}
func defaultDataHome() string {
	if v := os.Getenv("XDG_DATA_HOME"); v != "" {
		return v
	}
	return filepath.Join(os.Getenv("HOME"), ".local", "share")
}
func singleLine(s string) string {
	return strings.Join(strings.Fields(strings.ReplaceAll(strings.ReplaceAll(s, "\n", " "), "\r", " ")), " ")
}
func domainOf(url string) string {
	trimmed := strings.TrimPrefix(strings.TrimPrefix(url, "https://"), "http://")
	if i := strings.IndexByte(trimmed, '/'); i >= 0 {
		return trimmed[:i]
	}
	return trimmed
}
func esc(s string) string {
	return strings.ReplaceAll(strings.ReplaceAll(singleLine(s), `\`, `\\`), `;`, `\;`)
}
func desktopContent(name string, p CreatePlanData) string {
	return fmt.Sprintf("[Desktop Entry]\nType=Application\nName=%s\nComment=%s Web Application\nExec=%s\nIcon=%s\nTerminal=false\nCategories=Network;WebBrowser;\nStartupNotify=true\nStartupWMClass=%s\nX-Hypr-WebApp=true\nX-Hypr-WebApp-URL=%s\nX-Hypr-WebApp-Browser=%s\n", esc(name), esc(name), p.LauncherPath, esc(p.IconPath), p.Class, esc(p.URL), esc(p.Browser))
}
func launcherContent(p CreatePlanData) string {
	return fmt.Sprintf("#!/usr/bin/env bash\nset -euo pipefail\nurl=%q\nprofile=%q\nclass=%q\nbrowser=%q\nmkdir -p \"$profile\"\ncase \"$browser\" in\n  chromium|brave|brave-browser)\n    exec \"$browser\" --app=\"$url\" --new-window --class=\"$class\" --user-data-dir=\"$profile\"\n    ;;\n  flatpak:com.brave.Browser)\n    exec flatpak run com.brave.Browser --app=\"$url\" --new-window --class=\"$class\" --user-data-dir=\"$profile\"\n    ;;\n  *) exec \"$browser\" \"$url\" ;;\nesac\n", p.URL, p.ProfilePath, p.Class, p.Browser)
}
