package wallpaper

import (
	"encoding/json"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"
)

func TestWriteMonitorStateUsesSanitizedOutputName(t *testing.T) {
	tmp := t.TempDir()
	m := NewManager(io.Discard, io.Discard)
	m.StateDir = filepath.Join(tmp, "state")
	wallpaper := filepath.Join(tmp, "wall.png")
	if err := os.WriteFile(wallpaper, []byte("x"), 0o600); err != nil {
		t.Fatalf("write wallpaper: %v", err)
	}

	if err := m.WriteMonitorState("HDMI-A-1", "static", wallpaper); err != nil {
		t.Fatalf("WriteMonitorState: %v", err)
	}

	got := readTrim(filepath.Join(m.StateDir, "monitors", "HDMI-A-1.state"))
	want := "mode=static\npath=" + wallpaper
	if got != want {
		t.Fatalf("state = %q, want %q", got, want)
	}
}

func TestWriteHyprpaperConfigIncludesMonitorSpecificWallpapers(t *testing.T) {
	tmp := t.TempDir()
	m := NewManager(io.Discard, io.Discard)
	m.HyprpaperConf = filepath.Join(tmp, "hyprpaper.conf")
	wallA := filepath.Join(tmp, "a.png")
	wallB := filepath.Join(tmp, "b.png")
	for _, path := range []string{wallA, wallB} {
		if err := os.WriteFile(path, []byte("x"), 0o600); err != nil {
			t.Fatalf("write %s: %v", path, err)
		}
	}
	states := []MonitorState{{Output: "DP-3", Mode: "static", Path: wallA}, {Output: "HDMI-A-1", Mode: "static", Path: wallB}}

	if err := m.writeHyprpaperMonitorConfig(states); err != nil {
		t.Fatalf("writeHyprpaperMonitorConfig: %v", err)
	}

	content := readTrim(m.HyprpaperConf)
	for _, want := range []string{"monitor = DP-3", "path = " + wallA, "monitor = HDMI-A-1", "path = " + wallB} {
		if !strings.Contains(content, want) {
			t.Fatalf("hyprpaper.conf missing %q:\n%s", want, content)
		}
	}
}

func TestWriteMonitorStateMirrorsCurrentThemeMonitorWallpaper(t *testing.T) {
	tmp := t.TempDir()
	m := NewManager(io.Discard, io.Discard)
	m.StateHome = filepath.Join(tmp, "state")
	m.StateDir = filepath.Join(m.StateHome, "hypr-wallpaper")
	currentTheme := filepath.Join(m.StateHome, "orgm-theme", "current")
	if err := os.MkdirAll(filepath.Dir(currentTheme), 0o755); err != nil {
		t.Fatalf("mkdir theme state: %v", err)
	}
	if err := os.WriteFile(currentTheme, []byte("orgm-light\n"), 0o644); err != nil {
		t.Fatalf("write current theme: %v", err)
	}
	wallpaper := filepath.Join(tmp, "monitor.png")

	if err := m.WriteMonitorState("DP-3", "static", wallpaper); err != nil {
		t.Fatalf("WriteMonitorState: %v", err)
	}

	themeState := filepath.Join(m.StateHome, "orgm-theme", "wallpapers", "orgm-light.monitors", "DP-3.state")
	got := readTrim(themeState)
	want := "mode=static\npath=" + wallpaper
	if got != want {
		t.Fatalf("theme monitor wallpaper state = %q, want %q", got, want)
	}
}

func TestWriteStateDoesNotMirrorWhenStateDirIsOverridden(t *testing.T) {
	tmp := t.TempDir()
	m := NewManager(io.Discard, io.Discard)
	m.StateHome = filepath.Join(tmp, "real-state")
	m.StateDir = filepath.Join(tmp, "custom", "hypr-wallpaper")
	m.StateFile = filepath.Join(m.StateDir, "state")
	currentTheme := filepath.Join(m.StateHome, "orgm-theme", "current")
	if err := os.MkdirAll(filepath.Dir(currentTheme), 0o755); err != nil {
		t.Fatalf("mkdir theme state: %v", err)
	}
	if err := os.WriteFile(currentTheme, []byte("orgm-light\n"), 0o644); err != nil {
		t.Fatalf("write current theme: %v", err)
	}

	if err := m.WriteState("video", filepath.Join(tmp, "live.mp4")); err != nil {
		t.Fatalf("WriteState: %v", err)
	}

	themeState := filepath.Join(m.StateHome, "orgm-theme", "wallpapers", "orgm-light.state")
	if got := readTrim(themeState); got != "" {
		t.Fatalf("theme wallpaper state = %q, want no mirror for overridden StateDir", got)
	}
}

func TestWriteStateMirrorsCurrentThemeWallpaper(t *testing.T) {
	tmp := t.TempDir()
	m := NewManager(io.Discard, io.Discard)
	m.StateHome = filepath.Join(tmp, "state")
	m.StateDir = filepath.Join(m.StateHome, "hypr-wallpaper")
	m.StateFile = filepath.Join(m.StateDir, "state")
	currentTheme := filepath.Join(m.StateHome, "orgm-theme", "current")
	if err := os.MkdirAll(filepath.Dir(currentTheme), 0o755); err != nil {
		t.Fatalf("mkdir theme state: %v", err)
	}
	if err := os.WriteFile(currentTheme, []byte("orgm-light\n"), 0o644); err != nil {
		t.Fatalf("write current theme: %v", err)
	}
	wallpaper := filepath.Join(tmp, "wall.png")

	if err := m.WriteState("static", wallpaper); err != nil {
		t.Fatalf("WriteState: %v", err)
	}

	themeState := filepath.Join(m.StateHome, "orgm-theme", "wallpapers", "orgm-light.state")
	got := readTrim(themeState)
	want := "mode=static\npath=" + wallpaper
	if got != want {
		t.Fatalf("theme wallpaper state = %q, want %q", got, want)
	}
}

func TestSetVideoForMonitorStopsGlobalVideoWallpaper(t *testing.T) {
	tmp := t.TempDir()
	bin := filepath.Join(tmp, "bin")
	mpvpaper := filepath.Join(bin, "mpvpaper")
	if err := os.MkdirAll(bin, 0o755); err != nil {
		t.Fatalf("mkdir bin: %v", err)
	}
	if err := os.WriteFile(mpvpaper, []byte("#!/usr/bin/env bash\nexec -a mpvpaper sleep 30\n"), 0o755); err != nil {
		t.Fatalf("write mpvpaper: %v", err)
	}
	global := exec.Command(mpvpaper, "-o", "no-audio", "*", filepath.Join(tmp, "old.mp4"))
	if err := global.Start(); err != nil {
		t.Fatalf("start global mpvpaper: %v", err)
	}
	done := make(chan error, 1)
	go func() { done <- global.Wait() }()
	t.Cleanup(func() { _ = global.Process.Kill() })

	m := NewManager(io.Discard, io.Discard)
	m.StateDir = filepath.Join(tmp, "state", "hypr-wallpaper")
	m.StateFile = filepath.Join(m.StateDir, "state")
	m.CurrentFile = filepath.Join(tmp, "runtime", "hypr-random-wallpaper.current")
	m.LockWallpaper = filepath.Join(tmp, "runtime", "hypr-current-wallpaper")
	m.RuntimeDir = filepath.Join(tmp, "runtime")
	m.MPVPaperPIDFile = filepath.Join(m.RuntimeDir, "hypr-random-wallpaper.mpvpaper.pid")
	m.MPVPaperBin = mpvpaper
	m.KillBin = "kill"
	if err := os.MkdirAll(m.RuntimeDir, 0o755); err != nil {
		t.Fatalf("mkdir runtime: %v", err)
	}
	if err := os.WriteFile(m.MPVPaperPIDFile, []byte(strconv.Itoa(global.Process.Pid)+"\n"), 0o644); err != nil {
		t.Fatalf("write global pid: %v", err)
	}
	video := filepath.Join(tmp, "live.mp4")
	if err := os.WriteFile(video, []byte("video"), 0o600); err != nil {
		t.Fatalf("write video: %v", err)
	}

	if err := m.SetVideoForMonitor(video, "DP-3"); err != nil {
		t.Fatalf("SetVideoForMonitor: %v", err)
	}

	select {
	case <-done:
	case <-time.After(2 * time.Second):
		t.Fatalf("global mpvpaper pid %d still alive", global.Process.Pid)
	}
	if got := readTrim(m.MPVPaperPIDFile); got != "" {
		t.Fatalf("global pid file = %q, want removed", got)
	}
	monitorPID := readTrim(m.monitorMPVPaperPIDFile("DP-3"))
	if monitorPID == "" {
		t.Fatalf("monitor mpvpaper pid was not written")
	}
}

func TestSetVideoForMonitorStopsUntrackedMonitorVideoWallpaper(t *testing.T) {
	tmp := t.TempDir()
	video := filepath.Join(tmp, "live.mp4")
	oldVideo := filepath.Join(tmp, "old.mp4")
	for _, path := range []string{video, oldVideo} {
		if err := os.WriteFile(path, []byte("video"), 0o600); err != nil {
			t.Fatalf("write %s: %v", path, err)
		}
	}
	oldMonitor := exec.Command("bash", "-c", "exec -a \"mpvpaper -o no-audio loop hwdec=auto DP-3 "+oldVideo+"\" sleep 30")
	if err := oldMonitor.Start(); err != nil {
		t.Fatalf("start monitor mpvpaper: %v", err)
	}
	done := make(chan error, 1)
	go func() { done <- oldMonitor.Wait() }()
	t.Cleanup(func() { _ = oldMonitor.Process.Kill() })

	m := NewManager(io.Discard, io.Discard)
	m.StateDir = filepath.Join(tmp, "state", "hypr-wallpaper")
	m.StateFile = filepath.Join(m.StateDir, "state")
	m.CurrentFile = filepath.Join(tmp, "runtime", "hypr-random-wallpaper.current")
	m.LockWallpaper = filepath.Join(tmp, "runtime", "hypr-current-wallpaper")
	m.RuntimeDir = filepath.Join(tmp, "runtime")
	m.MPVPaperPIDFile = filepath.Join(m.RuntimeDir, "hypr-random-wallpaper.mpvpaper.pid")
	m.MPVPaperBin = "true"
	m.KillBin = "kill"
	if err := os.MkdirAll(m.RuntimeDir, 0o755); err != nil {
		t.Fatalf("mkdir runtime: %v", err)
	}

	if err := m.SetVideoForMonitor(video, "DP-3"); err != nil {
		t.Fatalf("SetVideoForMonitor: %v", err)
	}

	select {
	case <-done:
	case <-time.After(2 * time.Second):
		t.Fatalf("untracked monitor mpvpaper pid %d still alive", oldMonitor.Process.Pid)
	}
}

func TestSetVideoForMonitorStopsUntrackedGlobalVideoWallpaper(t *testing.T) {
	tmp := t.TempDir()
	video := filepath.Join(tmp, "live.mp4")
	oldVideo := filepath.Join(tmp, "old.mp4")
	for _, path := range []string{video, oldVideo} {
		if err := os.WriteFile(path, []byte("video"), 0o600); err != nil {
			t.Fatalf("write %s: %v", path, err)
		}
	}
	global := exec.Command("bash", "-c", "exec -a \"mpvpaper -o no-audio loop hwdec=auto * "+oldVideo+"\" sleep 30")
	if err := global.Start(); err != nil {
		t.Fatalf("start global mpvpaper: %v", err)
	}
	done := make(chan error, 1)
	go func() { done <- global.Wait() }()
	t.Cleanup(func() { _ = global.Process.Kill() })

	m := NewManager(io.Discard, io.Discard)
	m.StateDir = filepath.Join(tmp, "state", "hypr-wallpaper")
	m.StateFile = filepath.Join(m.StateDir, "state")
	m.CurrentFile = filepath.Join(tmp, "runtime", "hypr-random-wallpaper.current")
	m.LockWallpaper = filepath.Join(tmp, "runtime", "hypr-current-wallpaper")
	m.RuntimeDir = filepath.Join(tmp, "runtime")
	m.MPVPaperPIDFile = filepath.Join(m.RuntimeDir, "hypr-random-wallpaper.mpvpaper.pid")
	m.MPVPaperBin = "true"
	m.KillBin = "kill"
	if err := os.MkdirAll(m.RuntimeDir, 0o755); err != nil {
		t.Fatalf("mkdir runtime: %v", err)
	}

	if err := m.SetVideoForMonitor(video, "DP-3"); err != nil {
		t.Fatalf("SetVideoForMonitor: %v", err)
	}

	select {
	case <-done:
	case <-time.After(2 * time.Second):
		t.Fatalf("untracked global mpvpaper pid %d still alive", global.Process.Pid)
	}
}

func TestWallpaperDaemonPIDRecognizesOrgmWallpaperCommand(t *testing.T) {
	proc := exec.Command("bash", "-c", "exec -a 'orgm-wallpaper daemon' sleep 30")
	if err := proc.Start(); err != nil {
		t.Fatalf("start daemon-shaped process: %v", err)
	}
	t.Cleanup(func() { _ = proc.Process.Kill() })

	m := NewManager(io.Discard, io.Discard)
	if !m.isWallpaperDaemonPID(strconv.Itoa(proc.Process.Pid)) {
		t.Fatalf("isWallpaperDaemonPID did not recognize orgm-wallpaper daemon")
	}
}

func TestNextHourlyWallpaperDelayAlignsToTopOfHour(t *testing.T) {
	at := time.Date(2026, 6, 11, 18, 13, 17, 0, time.UTC)
	got := nextHourlyWallpaperDelay(at)
	want := 46*time.Minute + 43*time.Second
	if got != want {
		t.Fatalf("delay = %s, want %s", got, want)
	}

	at = time.Date(2026, 6, 11, 19, 0, 0, 0, time.UTC)
	if got := nextHourlyWallpaperDelay(at); got != 0 {
		t.Fatalf("delay at hour boundary = %s, want 0", got)
	}
}

func TestSetRandomStaticForMonitorsAssignsDifferentWallpaperPerOutput(t *testing.T) {
	tmp := t.TempDir()
	staticDir := filepath.Join(tmp, "wallpapers")
	if err := os.MkdirAll(staticDir, 0o755); err != nil {
		t.Fatalf("mkdir static dir: %v", err)
	}
	wallA := filepath.Join(staticDir, "a.png")
	wallB := filepath.Join(staticDir, "b.png")
	for _, path := range []string{wallA, wallB} {
		if err := os.WriteFile(path, []byte("x"), 0o600); err != nil {
			t.Fatalf("write wallpaper %s: %v", path, err)
		}
	}

	m := NewManager(io.Discard, io.Discard)
	m.StaticDir = staticDir
	m.StateDir = filepath.Join(tmp, "state", "hypr-wallpaper")
	m.StateFile = filepath.Join(m.StateDir, "state")
	m.CurrentFile = filepath.Join(tmp, "runtime", "hypr-random-wallpaper.current")
	m.LockWallpaper = filepath.Join(tmp, "runtime", "hypr-current-wallpaper")
	m.HyprpaperConf = filepath.Join(tmp, "runtime", "hyprpaper.conf")
	m.HyprpaperBin = "true"
	m.KillBin = "true"

	if err := m.SetRandomStaticForMonitors([]string{"DP-3", "HDMI-A-1"}); err != nil {
		t.Fatalf("SetRandomStaticForMonitors: %v", err)
	}

	content := readTrim(m.HyprpaperConf)
	for _, want := range []string{"monitor = DP-3", "monitor = HDMI-A-1"} {
		if !strings.Contains(content, want) {
			t.Fatalf("hyprpaper config missing %q:\n%s", want, content)
		}
	}
	if strings.Count(content, "path = "+wallA) != 1 || strings.Count(content, "path = "+wallB) != 1 {
		t.Fatalf("expected each wallpaper once across monitors, got:\n%s", content)
	}
	if got := m.CurrentMode(); got != "static-random" {
		t.Fatalf("CurrentMode = %q, want static-random", got)
	}
}

func TestSetStaticForMonitorUpdatesGlobalCurrentMode(t *testing.T) {
	tmp := t.TempDir()
	m := NewManager(io.Discard, io.Discard)
	m.StateDir = filepath.Join(tmp, "state", "hypr-wallpaper")
	m.StateFile = filepath.Join(m.StateDir, "state")
	m.CurrentFile = filepath.Join(tmp, "runtime", "hypr-random-wallpaper.current")
	m.LockWallpaper = filepath.Join(tmp, "runtime", "hypr-current-wallpaper")
	m.HyprpaperConf = filepath.Join(tmp, "runtime", "hyprpaper.conf")
	m.HyprpaperBin = "true"
	m.KillBin = "true"
	wallpaper := filepath.Join(tmp, "wall.png")
	if err := os.WriteFile(wallpaper, []byte("x"), 0o600); err != nil {
		t.Fatalf("write wallpaper: %v", err)
	}
	if err := m.WriteState("video", filepath.Join(tmp, "live.mp4")); err != nil {
		t.Fatalf("WriteState: %v", err)
	}

	if err := m.SetStaticForMonitor(wallpaper, "DP-3", "static"); err != nil {
		t.Fatalf("SetStaticForMonitor: %v", err)
	}

	if got := m.CurrentMode(); got != "static" {
		t.Fatalf("CurrentMode = %q, want static", got)
	}
	if got := m.StateValue("path"); got != wallpaper {
		t.Fatalf("global path = %q, want %q", got, wallpaper)
	}
}

func TestGenerateCombinedQuickshellDataUsesCurrentModeForInitialTab(t *testing.T) {
	tmp := t.TempDir()
	staticDir := filepath.Join(tmp, "Pictures", "Wallpapers")
	videoDir := filepath.Join(tmp, "Videos", "wallpapers")
	stateDir := filepath.Join(tmp, "state", "hypr-wallpaper")
	if err := os.MkdirAll(staticDir, 0o755); err != nil {
		t.Fatalf("mkdir static: %v", err)
	}
	if err := os.MkdirAll(videoDir, 0o755); err != nil {
		t.Fatalf("mkdir video: %v", err)
	}
	staticPath := filepath.Join(staticDir, "a.png")
	videoPath := filepath.Join(videoDir, "live.mp4")
	if err := os.WriteFile(staticPath, []byte("static"), 0o600); err != nil {
		t.Fatalf("write static: %v", err)
	}
	if err := os.WriteFile(videoPath, []byte("video"), 0o600); err != nil {
		t.Fatalf("write video: %v", err)
	}

	m := NewManager(io.Discard, io.Discard)
	m.StaticDir = staticDir
	m.VideoDir = videoDir
	m.StateDir = stateDir
	m.StateFile = filepath.Join(stateDir, "state")
	m.QuickshellManifest = filepath.Join(stateDir, "wallpaper-picker.tsv")
	if err := m.WriteState("video", videoPath); err != nil {
		t.Fatalf("WriteState: %v", err)
	}

	jsonPath := filepath.Join(stateDir, "wallpaper-picker-combined.json")
	if err := m.GenerateCombinedQuickshellData(jsonPath); err != nil {
		t.Fatalf("GenerateCombinedQuickshellData failed: %v", err)
	}

	content, err := os.ReadFile(jsonPath)
	if err != nil {
		t.Fatalf("read json: %v", err)
	}
	var data CombinedPickerData
	if err := json.Unmarshal(content, &data); err != nil {
		t.Fatalf("json unmarshal: %v\n%s", err, content)
	}
	if data.InitialMode != "video" {
		t.Fatalf("initialMode = %q, want video", data.InitialMode)
	}
	if len(data.Tabs["static"].Items) != 1 {
		t.Fatalf("static item count = %d, want 1", len(data.Tabs["static"].Items))
	}
	if len(data.Tabs["video"].Items) != 1 {
		t.Fatalf("video item count = %d, want 1", len(data.Tabs["video"].Items))
	}
}
