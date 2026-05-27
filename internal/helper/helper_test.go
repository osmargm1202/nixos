package helper

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestBuildCacheUsesMenuCategories(t *testing.T) {
	cache := BuildCache()
	if cache.SchemaVersion != 1 {
		t.Fatalf("schemaVersion = %d, want 1", cache.SchemaVersion)
	}
	if cache.DefaultCategory != "launchers" {
		t.Fatalf("defaultCategory = %q, want launchers", cache.DefaultCategory)
	}
	if len(cache.Categories) == 0 {
		t.Fatalf("cache categories empty")
	}
	if len(cache.Categories[0].Entries) == 0 {
		t.Fatalf("first category entries empty: %#v", cache.Categories[0])
	}
	if cache.Categories[0].Entries[0].Command != "orgm-hypr helper toggle" {
		t.Fatalf("first cache entry = %#v, want helper toggle", cache.Categories[0].Entries[0])
	}
}

func TestInitWritesValidJSON(t *testing.T) {
	state := t.TempDir()
	var out, errOut strings.Builder
	if err := Run([]string{"init", "--state-home", state}, &out, &errOut); err != nil {
		t.Fatalf("Run(init) error = %v", err)
	}
	path := filepath.Join(state, "orgm-helper", "keybindings.json")
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read cache: %v", err)
	}
	var cache Cache
	if err := json.Unmarshal(data, &cache); err != nil {
		t.Fatalf("cache json invalid: %v\n%s", err, data)
	}
	if !strings.Contains(out.String(), path) {
		t.Fatalf("stdout = %q, want cache path", out.String())
	}
}

func TestTogglePrintWritesCacheAndRequest(t *testing.T) {
	state := t.TempDir()
	configHome := filepath.Join(t.TempDir(), "config")
	t.Setenv("XDG_CONFIG_HOME", configHome)
	var out, errOut strings.Builder
	if err := Run([]string{"toggle", "--state-home", state, "--print"}, &out, &errOut); err != nil {
		t.Fatalf("Run(toggle --print) error = %v", err)
	}
	for _, rel := range []string{"keybindings.json", "keyhelper-request.json"} {
		path := filepath.Join(state, "orgm-helper", rel)
		if _, err := os.Stat(path); err != nil {
			t.Fatalf("expected %s: %v", path, err)
		}
	}
	wantPath := filepath.Join(configHome, "quickshell", "modules", "keyhelper", "shell.qml")
	got := out.String()
	if !strings.Contains(got, "ORGM_HELPER_CACHE="+filepath.Join(state, "orgm-helper", "keybindings.json")) ||
		!strings.Contains(got, "ORGM_HELPER_REQUEST="+filepath.Join(state, "orgm-helper", "keyhelper-request.json")) ||
		!strings.Contains(got, "ORGM_HELPER_SHOW=1") ||
		!strings.Contains(got, "quickshell -p ") ||
		!strings.Contains(got, wantPath) {
		t.Fatalf("stdout = %q, want env launch command for %q", got, wantPath)
	}
}

func TestToggleDoesNotLaunchQuickshellWhenKeyhelperAlreadyRunning(t *testing.T) {
	state := t.TempDir()
	bin := t.TempDir()
	logPath := filepath.Join(t.TempDir(), "quickshell.log")
	writeExecutable(t, filepath.Join(bin, "pgrep"), "#!/bin/sh\nexit 0\n")
	writeExecutable(t, filepath.Join(bin, "quickshell"), "#!/bin/sh\necho launched >>\"$ORGM_TEST_LOG\"\n")
	t.Setenv("PATH", bin)
	t.Setenv("ORGM_TEST_LOG", logPath)
	var out, errOut strings.Builder

	if err := Run([]string{"toggle", "--state-home", state}, &out, &errOut); err != nil {
		t.Fatalf("Run(toggle) error = %v", err)
	}

	requestPath := filepath.Join(state, "orgm-helper", "keyhelper-request.json")
	if _, err := os.Stat(requestPath); err != nil {
		t.Fatalf("expected request file %s: %v", requestPath, err)
	}
	if data, err := os.ReadFile(logPath); err == nil {
		t.Fatalf("quickshell log = %q, want no launch", data)
	} else if !os.IsNotExist(err) {
		t.Fatalf("read quickshell log: %v", err)
	}
}

func TestToggleLaunchesQuickshellWhenKeyhelperIsNotRunning(t *testing.T) {
	state := t.TempDir()
	bin := t.TempDir()
	configHome := filepath.Join(t.TempDir(), "config")
	logPath := filepath.Join(t.TempDir(), "quickshell.log")
	writeExecutable(t, filepath.Join(bin, "pgrep"), "#!/bin/sh\nexit 1\n")
	writeExecutable(t, filepath.Join(bin, "quickshell"), "#!/bin/sh\necho launch:$* cache:${ORGM_HELPER_CACHE:-} request:${ORGM_HELPER_REQUEST:-} show:${ORGM_HELPER_SHOW:-} >>\"$ORGM_TEST_LOG\"\n")
	t.Setenv("PATH", bin)
	t.Setenv("XDG_CONFIG_HOME", configHome)
	t.Setenv("ORGM_TEST_LOG", logPath)
	var out, errOut strings.Builder

	if err := Run([]string{"toggle", "--state-home", state}, &out, &errOut); err != nil {
		t.Fatalf("Run(toggle) error = %v", err)
	}

	wantPath := filepath.Join(configHome, "quickshell", "modules", "keyhelper", "shell.qml")
	waitForFileContains(t, logPath, "launch:-p "+wantPath)
	waitForFileContains(t, logPath, "cache:"+filepath.Join(state, "orgm-helper", "keybindings.json"))
	waitForFileContains(t, logPath, "request:"+filepath.Join(state, "orgm-helper", "keyhelper-request.json"))
	waitForFileContains(t, logPath, "show:1")
}

func TestToggleFallsBackToHostExecWhenQuickshellMissing(t *testing.T) {
	state := t.TempDir()
	bin := t.TempDir()
	configHome := filepath.Join(t.TempDir(), "config")
	logPath := filepath.Join(t.TempDir(), "host-exec.log")
	writeExecutable(t, filepath.Join(bin, "pgrep"), "#!/bin/sh\nexit 1\n")
	writeExecutable(t, filepath.Join(bin, "distrobox-host-exec"), "#!/bin/sh\necho hostexec:$* >>\"$ORGM_TEST_LOG\"\n")
	t.Setenv("PATH", bin)
	t.Setenv("XDG_CONFIG_HOME", configHome)
	t.Setenv("ORGM_TEST_LOG", logPath)
	var out, errOut strings.Builder

	if err := Run([]string{"toggle", "--state-home", state}, &out, &errOut); err != nil {
		t.Fatalf("Run(toggle) error = %v", err)
	}

	wantPath := filepath.Join(configHome, "quickshell", "modules", "keyhelper", "shell.qml")
	waitForFileContains(t, logPath, "hostexec:sh -lc")
	waitForFileContains(t, logPath, "ORGM_HELPER_CACHE="+filepath.Join(state, "orgm-helper", "keybindings.json"))
	waitForFileContains(t, logPath, "ORGM_HELPER_REQUEST="+filepath.Join(state, "orgm-helper", "keyhelper-request.json"))
	waitForFileContains(t, logPath, "ORGM_HELPER_SHOW=1")
	waitForFileContains(t, logPath, "quickshell -p "+wantPath)
}

func writeExecutable(t *testing.T, path, content string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		t.Fatalf("MkdirAll() error = %v", err)
	}
	if err := os.WriteFile(path, []byte(content), 0o700); err != nil {
		t.Fatalf("WriteFile() error = %v", err)
	}
}

func readFile(t *testing.T, path string) string {
	t.Helper()
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("ReadFile(%q) error = %v", path, err)
	}
	return string(data)
}

func waitForFileContains(t *testing.T, path, want string) {
	t.Helper()
	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		data, err := os.ReadFile(path)
		if err == nil && strings.Contains(string(data), want) {
			return
		}
		time.Sleep(10 * time.Millisecond)
	}
	data, _ := os.ReadFile(path)
	t.Fatalf("file %q = %q, want substring %q", path, string(data), want)
}

func TestRunRejectsInvalidSubcommand(t *testing.T) {
	var out, errOut strings.Builder
	err := Run([]string{"wat"}, &out, &errOut)
	if err == nil || !strings.Contains(err.Error(), "usage: orgm-hypr helper [init|toggle]") {
		t.Fatalf("err = %v, want usage", err)
	}
}
