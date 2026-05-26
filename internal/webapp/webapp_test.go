package webapp

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestCreatePlanNormalizesSlugURLAndPaths(t *testing.T) {
	root := t.TempDir()
	plan, err := CreatePlan(CreateOptions{DataHome: root, Name: "Mi App!", URL: "example.com/path", Browser: "chromium"})
	if err != nil {
		t.Fatalf("CreatePlan() error = %v", err)
	}
	if plan.Slug != "mi-app" || plan.URL != "https://example.com/path" {
		t.Fatalf("slug/url = %q/%q, want mi-app/https://example.com/path", plan.Slug, plan.URL)
	}
	if got, want := plan.DesktopPath, filepath.Join(root, "applications", "mi-app.desktop"); got != want {
		t.Fatalf("DesktopPath = %q, want %q", got, want)
	}
	if !strings.Contains(plan.DesktopContent, "X-Hypr-WebApp=true\n") || !strings.Contains(plan.DesktopContent, "Exec="+plan.LauncherPath+"\n") {
		t.Fatalf("DesktopContent = %q, want Hypr marker and launcher exec", plan.DesktopContent)
	}
	if !strings.Contains(plan.LauncherContent, `--app="$url"`) || !strings.Contains(plan.LauncherContent, "chromium") {
		t.Fatalf("LauncherContent = %q, want chromium app launcher", plan.LauncherContent)
	}
}

func TestListDiscoversOnlyHyprWebApps(t *testing.T) {
	root := t.TempDir()
	writeTestFile(t, filepath.Join(root, "applications", "chat.desktop"), "[Desktop Entry]\nName=Chat\nX-Hypr-WebApp=true\nX-Hypr-WebApp-URL=https://chat.example\nExec=/tmp/launcher\n")
	writeTestFile(t, filepath.Join(root, "applications", "normal.desktop"), "[Desktop Entry]\nName=Normal\n")
	apps, err := List(root)
	if err != nil {
		t.Fatalf("List() error = %v", err)
	}
	if len(apps) != 1 || apps[0].Name != "Chat" || apps[0].URL != "https://chat.example" {
		t.Fatalf("apps = %#v, want Chat webapp only", apps)
	}
}

func TestRemovePlanRequiresExplicitProfileConfirmation(t *testing.T) {
	root := t.TempDir()
	desktop := filepath.Join(root, "applications", "chat.desktop")
	execPath := filepath.Join(root, "hypr", "webapps", "bin", "hypr-webapp-chat")
	writeTestFile(t, desktop, "[Desktop Entry]\nName=Chat\nX-Hypr-WebApp=true\nExec="+execPath+"\n")
	plan, err := RemovePlan(RemoveOptions{DataHome: root, DesktopPath: desktop, RemoveProfile: true, Confirm: ""})
	if err == nil {
		t.Fatalf("RemovePlan() error = nil, want confirmation error")
	}
	plan, err = RemovePlan(RemoveOptions{DataHome: root, DesktopPath: desktop, RemoveProfile: true, Confirm: "delete-profile"})
	if err != nil {
		t.Fatalf("RemovePlan() confirmed error = %v", err)
	}
	if len(plan.RemovePaths) != 3 || plan.RemovePaths[2] != filepath.Join(root, "hypr", "webapps", "profiles", "chat") {
		t.Fatalf("RemovePaths = %#v, want desktop launcher profile", plan.RemovePaths)
	}
}

func writeTestFile(t *testing.T, path, content string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		t.Fatalf("MkdirAll() error = %v", err)
	}
	if err := os.WriteFile(path, []byte(content), 0o600); err != nil {
		t.Fatalf("WriteFile() error = %v", err)
	}
}
