package calendar

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestRunSyncParsesDefaultGcalcliTSVAndWritesCache(t *testing.T) {
	root := t.TempDir()
	writeExecutable(t, filepath.Join(root, "bin", "gcal-fixture"), "#!/bin/sh\nprintf '%s\n' '2026-05-24T10:00:00Z\t2026-05-24T11:00:00Z\tProject review\tPersonal\thttps://event.example/review' '2026-05-25\t2026-05-26\tAll day task\tWork\t'\n")
	writeExecutable(t, filepath.Join(root, "bin", "notify-send"), "#!/bin/sh\nexit 0\n")
	t.Setenv("PATH", filepath.Join(root, "bin")+string(os.PathListSeparator)+os.Getenv("PATH"))
	t.Setenv("XDG_CACHE_HOME", filepath.Join(root, "cache"))
	t.Setenv("XDG_STATE_HOME", filepath.Join(root, "state"))
	t.Setenv("ORGM_CALENDAR_GCALCLI_CMD", filepath.Join(root, "bin", "gcal-fixture"))
	t.Setenv("ORGM_CALENDAR_NOW", "2026-05-23T10:00:00Z")

	if err := Run([]string{"sync"}, nil, nil); err != nil {
		t.Fatalf("Run(sync) error = %v", err)
	}
	cacheFile := filepath.Join(root, "cache", "orgm-calendar", "events.json")
	cacheText := readFile(t, cacheFile)
	if !strings.Contains(cacheText, `"backend": "gcalcli"`) || !strings.Contains(cacheText, `"command":`) {
		t.Fatalf("cache JSON = %s, want lower-case source backend/command keys", cacheText)
	}
	cache := readJSON[Cache](t, cacheFile)
	if got, want := cache.SchemaVersion, 1; got != want {
		t.Fatalf("schemaVersion=%d want %d", got, want)
	}
	if got, want := cache.Source.Backend, "gcalcli"; got != want {
		t.Fatalf("backend=%q want %q", got, want)
	}
	if got := cache.Source.Command; !strings.Contains(got, "gcal-fixture") {
		t.Fatalf("command=%q want fixture command", got)
	}
	if got, want := len(cache.Events), 2; got != want {
		t.Fatalf("events=%d want %d", got, want)
	}
	if got, want := cache.Events[0].Title, "Project review"; got != want {
		t.Fatalf("first title=%q want %q", got, want)
	}
	if got, want := cache.Events[0].HTMLLink, "https://event.example/review"; got != want {
		t.Fatalf("htmlLink=%q want %q", got, want)
	}
	if cache.Events[1].AllDay != true {
		t.Fatalf("second event allDay=false want true")
	}
}

func TestRunSyncPreservesExistingCacheOnParseFailure(t *testing.T) {
	root := t.TempDir()
	cachePath := filepath.Join(root, "cache", "orgm-calendar", "events.json")
	writeFile(t, cachePath, `{"schemaVersion":1,"events":[{"title":"keep me"}]}`)
	writeExecutable(t, filepath.Join(root, "gcal-bad"), "#!/bin/sh\nprintf '%s\n' 'not-json-without-tabs'\n")
	t.Setenv("XDG_CACHE_HOME", filepath.Join(root, "cache"))
	t.Setenv("XDG_STATE_HOME", filepath.Join(root, "state"))
	t.Setenv("ORGM_CALENDAR_GCALCLI_CMD", filepath.Join(root, "gcal-bad"))

	if err := Run([]string{"sync"}, nil, nil); err == nil {
		t.Fatalf("Run(sync) error = nil, want parse failure")
	}
	if got := readFile(t, cachePath); !strings.Contains(got, "keep me") {
		t.Fatalf("cache=%q, want previous valid cache preserved", got)
	}
	status := readJSON[Status](t, filepath.Join(root, "state", "orgm-calendar", "status.json"))
	if got, want := status.State, "parse_error"; got != want {
		t.Fatalf("status=%q want %q", got, want)
	}
	if !status.Stale {
		t.Fatalf("stale=false want true")
	}
}

func TestRunToggleUIWritesRequestAndStartsQuickshellOnlyWhenNeeded(t *testing.T) {
	root := t.TempDir()
	logPath := filepath.Join(root, "quick.log")
	writeExecutable(t, filepath.Join(root, "quickshell"), "#!/bin/sh\necho quickshell:$* >>\"$ORGM_TEST_LOG\"\n")
	t.Setenv("PATH", root+string(os.PathListSeparator)+os.Getenv("PATH"))
	t.Setenv("ORGM_TEST_LOG", logPath)
	t.Setenv("ORGM_CALENDAR_QUICKSHELL_CMD", filepath.Join(root, "quickshell"))
	t.Setenv("XDG_STATE_HOME", filepath.Join(root, "state"))
	t.Setenv("ORGM_CALENDAR_NOW", "2026-05-24T10:00:00Z")
	t.Setenv("ORGM_CALENDAR_UI_RUNNING", "0")

	if err := Run([]string{"toggle-ui"}, nil, nil); err != nil {
		t.Fatalf("Run(toggle-ui) error = %v", err)
	}
	request := readJSON[UIRequest](t, filepath.Join(root, "state", "orgm-calendar", "ui-request.json"))
	if got, want := request.Action, "toggle"; got != want {
		t.Fatalf("action=%q want %q", got, want)
	}
	if got, want := request.Source, "orgm-hypr calendar toggle-ui"; got != want {
		t.Fatalf("source=%q want %q", got, want)
	}
	if got := readFile(t, logPath); !strings.Contains(got, "quickshell:-c calendar") {
		t.Fatalf("quickshell log=%q", got)
	}

	t.Setenv("ORGM_CALENDAR_UI_RUNNING", "1")
	before := readFile(t, logPath)
	if err := Run([]string{"toggle-ui"}, nil, nil); err != nil {
		t.Fatalf("Run(toggle-ui running) error = %v", err)
	}
	if got := readFile(t, logPath); got != before {
		t.Fatalf("quickshell restarted: before=%q after=%q", before, got)
	}
}

func TestOpenEventUsesCachedLinkAndStatusPrintsCachePath(t *testing.T) {
	root := t.TempDir()
	logPath := filepath.Join(root, "open.log")
	writeFile(t, filepath.Join(root, "cache", "orgm-calendar", "events.json"), `{"schemaVersion":1,"events":[{"id":"event-1","stableKey":"stable-1","startDate":"2026-05-24","htmlLink":"https://event.example/1"}]}`)
	writeExecutable(t, filepath.Join(root, "open"), "#!/bin/sh\necho open:$* >>\"$ORGM_TEST_LOG\"\n")
	t.Setenv("XDG_CACHE_HOME", filepath.Join(root, "cache"))
	t.Setenv("XDG_STATE_HOME", filepath.Join(root, "state"))
	t.Setenv("ORGM_CALENDAR_OPEN_CMD", filepath.Join(root, "open"))
	t.Setenv("ORGM_TEST_LOG", logPath)

	if err := Run([]string{"open-event", "event-1"}, nil, nil); err != nil {
		t.Fatalf("Run(open-event) error = %v", err)
	}
	if got := readFile(t, logPath); !strings.Contains(got, "https://event.example/1") {
		t.Fatalf("open log=%q", got)
	}
	var out strings.Builder
	if err := Run([]string{"status"}, &out, nil); err != nil {
		t.Fatalf("Run(status) error = %v", err)
	}
	if got := out.String(); !strings.Contains(got, filepath.Join(root, "cache", "orgm-calendar", "events.json")) {
		t.Fatalf("status output=%q", got)
	}
}

func writeFile(t *testing.T, path, content string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(content), 0o600); err != nil {
		t.Fatal(err)
	}
}
func writeExecutable(t *testing.T, path, content string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(content), 0o700); err != nil {
		t.Fatal(err)
	}
}
func readFile(t *testing.T, path string) string {
	t.Helper()
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	return string(data)
}
func readJSON[T any](t *testing.T, path string) T {
	t.Helper()
	var out T
	if err := json.Unmarshal([]byte(readFile(t, path)), &out); err != nil {
		t.Fatal(err)
	}
	return out
}
