package wallpaper

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestBuildPickerDataStatic(t *testing.T) {
	manifest := strings.NewReader(strings.Join([]string{
		"static\t/home/test/Pictures/Wallpapers/a.png",
		"video\t/home/test/Videos/wallpapers/live.mp4",
		"static\t/home/test/Pictures/Wallpapers/nested/b.jpg",
	}, "\n"))

	data, err := BuildPickerData(DataOptions{
		Mode:         "static",
		ManifestPath: "manifest.tsv",
		JSONPath:     "picker.json",
		CurrentPath:  "/home/test/Pictures/Wallpapers/a.png",
		Script:       "/home/test/.local/bin/hypr-random-wallpaper",
	}, manifest)
	if err != nil {
		t.Fatalf("BuildPickerData failed: %v", err)
	}

	if data.Mode != "static" {
		t.Fatalf("mode = %q, want static", data.Mode)
	}
	if data.Title != "Normal wallpapers" {
		t.Fatalf("title = %q", data.Title)
	}
	if data.ApplyCommand != "set-static" {
		t.Fatalf("applyCommand = %q", data.ApplyCommand)
	}
	if data.Script != "/home/test/.local/bin/hypr-random-wallpaper" {
		t.Fatalf("script = %q", data.Script)
	}
	if data.Current != "/home/test/Pictures/Wallpapers/a.png" {
		t.Fatalf("current = %q", data.Current)
	}
	if len(data.Items) != 2 {
		t.Fatalf("item count = %d, want 2", len(data.Items))
	}
	if data.Items[0].Name != "a.png" {
		t.Fatalf("first name = %q", data.Items[0].Name)
	}
	if data.Items[0].Thumb != "/home/test/Pictures/Wallpapers/.thumb/a.png.jpg" {
		t.Fatalf("first thumb = %q", data.Items[0].Thumb)
	}
	if data.Items[1].Thumb != "/home/test/Pictures/Wallpapers/nested/.thumb/b.jpg.jpg" {
		t.Fatalf("second thumb = %q", data.Items[1].Thumb)
	}
}

func TestBuildPickerDataVideo(t *testing.T) {
	manifest := strings.NewReader("static\t/x/a.png\nvideo\t/home/test/Videos/wallpapers/live.mp4\n")

	data, err := BuildPickerData(DataOptions{
		Mode:         "video",
		ManifestPath: "manifest.tsv",
		JSONPath:     "picker.json",
	}, manifest)
	if err != nil {
		t.Fatalf("BuildPickerData failed: %v", err)
	}

	if data.Title != "Live wallpapers" {
		t.Fatalf("title = %q", data.Title)
	}
	if data.ApplyCommand != "set-video" {
		t.Fatalf("applyCommand = %q", data.ApplyCommand)
	}
	if data.Script != "orgm-wallpaper" {
		t.Fatalf("script = %q", data.Script)
	}
	if len(data.ScriptArgs) != 0 {
		t.Fatalf("scriptArgs = %#v, want empty", data.ScriptArgs)
	}
	if len(data.Items) != 1 {
		t.Fatalf("item count = %d, want 1", len(data.Items))
	}
	if data.Items[0].Thumb != "/home/test/Videos/wallpapers/.thumb/live.mp4.jpg" {
		t.Fatalf("thumb = %q", data.Items[0].Thumb)
	}
}

func TestGeneratePickerDataWritesJSON(t *testing.T) {
	tmp := t.TempDir()
	manifestPath := filepath.Join(tmp, "manifest.tsv")
	jsonPath := filepath.Join(tmp, "wallpaper-picker.json")
	if err := os.WriteFile(manifestPath, []byte("static\t"+filepath.Join(tmp, "one.png")+"\n"), 0o600); err != nil {
		t.Fatalf("write manifest: %v", err)
	}

	err := GeneratePickerData(DataOptions{
		Mode:         "static",
		ManifestPath: manifestPath,
		JSONPath:     jsonPath,
		CurrentPath:  filepath.Join(tmp, "one.png"),
		Script:       "hypr-random-wallpaper",
	})
	if err != nil {
		t.Fatalf("GeneratePickerData failed: %v", err)
	}

	content, err := os.ReadFile(jsonPath)
	if err != nil {
		t.Fatalf("read json: %v", err)
	}
	var data PickerData
	if err := json.Unmarshal(content, &data); err != nil {
		t.Fatalf("json unmarshal: %v\n%s", err, content)
	}
	if data.Items[0].Thumb != filepath.Join(tmp, ".thumb", "one.png.jpg") {
		t.Fatalf("thumb = %q", data.Items[0].Thumb)
	}
	if !strings.HasSuffix(string(content), "\n") {
		t.Fatalf("json output should end with newline")
	}
}

func TestBuildPickerDataRejectsInvalidMode(t *testing.T) {
	_, err := BuildPickerData(DataOptions{Mode: "bad", ManifestPath: "manifest.tsv", JSONPath: "picker.json"}, strings.NewReader(""))
	if err == nil {
		t.Fatal("expected error")
	}
}

func TestBuildCombinedPickerDataIncludesMonitors(t *testing.T) {
	manifest := strings.NewReader("static\t/home/test/Pictures/Wallpapers/a.png\n")

	data, err := BuildCombinedPickerData(CombinedDataOptions{
		ManifestPath: "manifest.tsv",
		JSONPath:     "picker.json",
		Monitors:     []PickerMonitor{{Name: "DP-3", Description: "main"}, {Name: "HDMI-A-1", Description: "side"}},
	}, manifest)
	if err != nil {
		t.Fatalf("BuildCombinedPickerData failed: %v", err)
	}
	if len(data.Monitors) != 2 {
		t.Fatalf("monitor count = %d, want 2", len(data.Monitors))
	}
	if data.Monitors[0].Name != "DP-3" || data.Monitors[1].Name != "HDMI-A-1" {
		t.Fatalf("monitors = %#v", data.Monitors)
	}
}

func TestBuildCombinedPickerDataIncludesNormalAndLiveTabs(t *testing.T) {
	manifest := strings.NewReader(strings.Join([]string{
		"static\t/home/test/Pictures/Wallpapers/a.png",
		"video\t/home/test/Videos/wallpapers/live.mp4",
		"static\t/home/test/Pictures/Wallpapers/b.jpg",
	}, "\n"))

	data, err := BuildCombinedPickerData(CombinedDataOptions{
		ManifestPath: "manifest.tsv",
		JSONPath:     "picker.json",
		InitialMode:  "video",
		CurrentMode:  "video",
		CurrentPath:  "/home/test/Videos/wallpapers/live.mp4",
	}, manifest)
	if err != nil {
		t.Fatalf("BuildCombinedPickerData failed: %v", err)
	}

	if data.Mode != "combined" {
		t.Fatalf("mode = %q, want combined", data.Mode)
	}
	if data.InitialMode != "video" {
		t.Fatalf("initialMode = %q, want video", data.InitialMode)
	}
	if data.Script != "orgm-wallpaper" {
		t.Fatalf("script = %q, want orgm-wallpaper", data.Script)
	}
	if len(data.ScriptArgs) != 0 {
		t.Fatalf("scriptArgs = %#v, want empty", data.ScriptArgs)
	}

	staticTab := data.Tabs["static"]
	if staticTab.Title != "Normal wallpapers" {
		t.Fatalf("static title = %q", staticTab.Title)
	}
	if staticTab.ApplyCommand != "set-static" {
		t.Fatalf("static apply = %q", staticTab.ApplyCommand)
	}
	if staticTab.RandomCommand != "random-static" {
		t.Fatalf("static random = %q", staticTab.RandomCommand)
	}
	if staticTab.Current != "" {
		t.Fatalf("static current = %q, want empty when current mode is video", staticTab.Current)
	}
	if len(staticTab.Items) != 2 {
		t.Fatalf("static item count = %d, want 2", len(staticTab.Items))
	}
	if staticTab.Items[0].Thumb != "/home/test/Pictures/Wallpapers/.thumb/a.png.jpg" {
		t.Fatalf("static first thumb = %q", staticTab.Items[0].Thumb)
	}

	videoTab := data.Tabs["video"]
	if videoTab.Title != "Live wallpapers" {
		t.Fatalf("video title = %q", videoTab.Title)
	}
	if videoTab.ApplyCommand != "set-video" {
		t.Fatalf("video apply = %q", videoTab.ApplyCommand)
	}
	if videoTab.RandomCommand != "random-video" {
		t.Fatalf("video random = %q", videoTab.RandomCommand)
	}
	if videoTab.Current != "/home/test/Videos/wallpapers/live.mp4" {
		t.Fatalf("video current = %q", videoTab.Current)
	}
	if len(videoTab.Items) != 1 {
		t.Fatalf("video item count = %d, want 1", len(videoTab.Items))
	}
}

func TestBuildCombinedPickerDataDefaultsInitialModeFromCurrentMode(t *testing.T) {
	manifest := strings.NewReader("static\t/x/a.png\nvideo\t/x/live.mp4\n")

	data, err := BuildCombinedPickerData(CombinedDataOptions{
		ManifestPath: "manifest.tsv",
		JSONPath:     "picker.json",
		CurrentMode:  "static-random",
		CurrentPath:  "/x/a.png",
	}, manifest)
	if err != nil {
		t.Fatalf("BuildCombinedPickerData failed: %v", err)
	}

	if data.InitialMode != "static" {
		t.Fatalf("initialMode = %q, want static", data.InitialMode)
	}
	if data.Tabs["static"].Current != "/x/a.png" {
		t.Fatalf("static current = %q", data.Tabs["static"].Current)
	}
	if data.Tabs["video"].Current != "" {
		t.Fatalf("video current = %q, want empty", data.Tabs["video"].Current)
	}
}

func TestGenerateCombinedPickerDataWritesJSON(t *testing.T) {
	tmp := t.TempDir()
	manifestPath := filepath.Join(tmp, "manifest.tsv")
	jsonPath := filepath.Join(tmp, "wallpaper-picker.json")
	manifest := "static\t" + filepath.Join(tmp, "one.png") + "\nvideo\t" + filepath.Join(tmp, "live.mp4") + "\n"
	if err := os.WriteFile(manifestPath, []byte(manifest), 0o600); err != nil {
		t.Fatalf("write manifest: %v", err)
	}

	err := GenerateCombinedPickerData(CombinedDataOptions{
		ManifestPath: manifestPath,
		JSONPath:     jsonPath,
		CurrentMode:  "video",
		CurrentPath:  filepath.Join(tmp, "live.mp4"),
	})
	if err != nil {
		t.Fatalf("GenerateCombinedPickerData failed: %v", err)
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
	if data.Tabs["video"].Items[0].Thumb != filepath.Join(tmp, ".thumb", "live.mp4.jpg") {
		t.Fatalf("video thumb = %q", data.Tabs["video"].Items[0].Thumb)
	}
	if !strings.HasSuffix(string(content), "\n") {
		t.Fatalf("json output should end with newline")
	}
}

func TestCleanStaleThumbnailsRemovesOnlyMissingSources(t *testing.T) {
	root := t.TempDir()
	current := filepath.Join(root, "current.png")
	validThumb := filepath.Join(root, ".thumb", "current.png.jpg")
	staleThumb := filepath.Join(root, ".thumb", "removed.png.jpg")
	nestedCurrent := filepath.Join(root, "nested", "keep.webp")
	nestedStaleThumb := filepath.Join(root, "nested", ".thumb", "gone.jpg.jpg")
	thumbSubdirFile := filepath.Join(root, ".thumb", "album", "personal.jpg")

	for _, dir := range []string{filepath.Join(root, ".thumb"), filepath.Join(root, "nested", ".thumb"), filepath.Join(root, ".thumb", "album")} {
		if err := os.MkdirAll(dir, 0o755); err != nil {
			t.Fatalf("mkdir %s: %v", dir, err)
		}
	}
	for _, file := range []string{current, nestedCurrent, validThumb, staleThumb, nestedStaleThumb, thumbSubdirFile} {
		if err := os.MkdirAll(filepath.Dir(file), 0o755); err != nil {
			t.Fatalf("mkdir parent %s: %v", file, err)
		}
		if err := os.WriteFile(file, []byte("x"), 0o600); err != nil {
			t.Fatalf("write %s: %v", file, err)
		}
	}

	if err := CleanStaleThumbnails(root); err != nil {
		t.Fatalf("CleanStaleThumbnails failed: %v", err)
	}

	assertMissing(t, staleThumb)
	assertMissing(t, nestedStaleThumb)
	assertExists(t, validThumb)
	assertExists(t, thumbSubdirFile)
}

func assertExists(t *testing.T, path string) {
	t.Helper()
	if _, err := os.Stat(path); err != nil {
		t.Fatalf("expected %s to exist: %v", path, err)
	}
}

func assertMissing(t *testing.T, path string) {
	t.Helper()
	if _, err := os.Stat(path); !os.IsNotExist(err) {
		t.Fatalf("expected %s to be removed, stat err=%v", path, err)
	}
}
