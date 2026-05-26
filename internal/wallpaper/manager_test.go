package wallpaper

import (
	"encoding/json"
	"io"
	"os"
	"path/filepath"
	"testing"
)

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
