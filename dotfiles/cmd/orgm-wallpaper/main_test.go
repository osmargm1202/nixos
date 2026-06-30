package main

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestSetStaticAcceptsMonitorFlag(t *testing.T) {
	root := t.TempDir()
	bin := filepath.Join(root, "bin")
	if err := os.MkdirAll(bin, 0o755); err != nil {
		t.Fatalf("mkdir bin: %v", err)
	}
	writeExecutable(t, filepath.Join(bin, "hyprpaper"), "#!/bin/sh\nexit 0\n")
	wallpaper := filepath.Join(root, "wall.png")
	if err := os.WriteFile(wallpaper, []byte("x"), 0o600); err != nil {
		t.Fatalf("write wallpaper: %v", err)
	}
	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))
	t.Setenv("HOME", root)
	t.Setenv("XDG_STATE_HOME", filepath.Join(root, "state"))
	t.Setenv("XDG_RUNTIME_DIR", filepath.Join(root, "runtime"))

	var stdout, stderr bytes.Buffer
	if err := runWithIO([]string{"set-static", wallpaper, "--monitor", "DP-3"}, &stdout, &stderr); err != nil {
		t.Fatalf("runWithIO set-static --monitor error = %v stderr=%s", err, stderr.String())
	}

	statePath := filepath.Join(root, "state", "hypr-wallpaper", "monitors", "DP-3.state")
	state, err := os.ReadFile(statePath)
	if err != nil {
		t.Fatalf("read monitor state: %v", err)
	}
	if got := string(state); !strings.Contains(got, "mode=static") || !strings.Contains(got, "path="+wallpaper) {
		t.Fatalf("state = %q, want static monitor wallpaper", got)
	}
}

func TestSetVideoAcceptsMonitorFlag(t *testing.T) {
	root := t.TempDir()
	bin := filepath.Join(root, "bin")
	calls := filepath.Join(root, "calls.log")
	writeExecutable(t, filepath.Join(bin, "mpvpaper"), "#!/bin/sh\nprintf '%s\\n' \"$*\" >>\"$CALLS\"\n")
	video := filepath.Join(root, "live.mp4")
	if err := os.WriteFile(video, []byte("video"), 0o600); err != nil {
		t.Fatalf("write video: %v", err)
	}
	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))
	t.Setenv("CALLS", calls)
	t.Setenv("HOME", root)
	t.Setenv("XDG_STATE_HOME", filepath.Join(root, "state"))
	t.Setenv("XDG_RUNTIME_DIR", filepath.Join(root, "runtime"))

	var stdout, stderr bytes.Buffer
	if err := runWithIO([]string{"set-video", video, "--monitor", "DP-3"}, &stdout, &stderr); err != nil {
		t.Fatalf("runWithIO set-video --monitor error = %v stderr=%s", err, stderr.String())
	}

	statePath := filepath.Join(root, "state", "hypr-wallpaper", "monitors", "DP-3.state")
	state, err := os.ReadFile(statePath)
	if err != nil {
		t.Fatalf("read monitor state: %v", err)
	}
	if got := string(state); !strings.Contains(got, "mode=video") || !strings.Contains(got, "path="+video) {
		t.Fatalf("state = %q, want video monitor wallpaper", got)
	}
	logged := readFile(t, calls)
	if !strings.Contains(logged, " DP-3 "+video) {
		t.Fatalf("mpvpaper calls = %q, want monitor-specific DP-3 video", logged)
	}
}

func TestRandomVideoAcceptsMonitorFlag(t *testing.T) {
	root := t.TempDir()
	bin := filepath.Join(root, "bin")
	writeExecutable(t, filepath.Join(bin, "mpvpaper"), "#!/bin/sh\nexit 0\n")
	videoDir := filepath.Join(root, "Videos", "wallpapers")
	video := filepath.Join(videoDir, "live.mp4")
	if err := os.MkdirAll(videoDir, 0o755); err != nil {
		t.Fatalf("mkdir video: %v", err)
	}
	if err := os.WriteFile(video, []byte("video"), 0o600); err != nil {
		t.Fatalf("write video: %v", err)
	}
	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))
	t.Setenv("HOME", root)
	t.Setenv("XDG_STATE_HOME", filepath.Join(root, "state"))
	t.Setenv("XDG_RUNTIME_DIR", filepath.Join(root, "runtime"))
	t.Setenv("HYPR_VIDEO_WALLPAPER_DIR", videoDir)

	var stdout, stderr bytes.Buffer
	if err := runWithIO([]string{"random", "video", "--monitor", "DP-3"}, &stdout, &stderr); err != nil {
		t.Fatalf("runWithIO random video --monitor error = %v stderr=%s", err, stderr.String())
	}

	statePath := filepath.Join(root, "state", "hypr-wallpaper", "monitors", "DP-3.state")
	state := readFile(t, statePath)
	if !strings.Contains(state, "mode=video") || !strings.Contains(state, "path="+video) {
		t.Fatalf("state = %q, want random video monitor wallpaper", state)
	}
}

func TestRandomVideoAliasAcceptsMonitorFlag(t *testing.T) {
	root := t.TempDir()
	bin := filepath.Join(root, "bin")
	writeExecutable(t, filepath.Join(bin, "mpvpaper"), "#!/bin/sh\nexit 0\n")
	videoDir := filepath.Join(root, "Videos", "wallpapers")
	video := filepath.Join(videoDir, "live.mp4")
	if err := os.MkdirAll(videoDir, 0o755); err != nil {
		t.Fatalf("mkdir video: %v", err)
	}
	if err := os.WriteFile(video, []byte("video"), 0o600); err != nil {
		t.Fatalf("write video: %v", err)
	}
	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))
	t.Setenv("HOME", root)
	t.Setenv("XDG_STATE_HOME", filepath.Join(root, "state"))
	t.Setenv("XDG_RUNTIME_DIR", filepath.Join(root, "runtime"))
	t.Setenv("HYPR_VIDEO_WALLPAPER_DIR", videoDir)

	var stdout, stderr bytes.Buffer
	if err := runWithIO([]string{"random-video", "--monitor", "DP-3"}, &stdout, &stderr); err != nil {
		t.Fatalf("runWithIO random-video --monitor error = %v stderr=%s", err, stderr.String())
	}

	state := readFile(t, filepath.Join(root, "state", "hypr-wallpaper", "monitors", "DP-3.state"))
	if !strings.Contains(state, "mode=video") || !strings.Contains(state, "path="+video) {
		t.Fatalf("state = %q, want random-video monitor wallpaper", state)
	}
}

func TestStatusAcceptsMonitorFlag(t *testing.T) {
	root := t.TempDir()
	wallpaper := filepath.Join(root, "wall.png")
	if err := os.WriteFile(wallpaper, []byte("x"), 0o600); err != nil {
		t.Fatalf("write wallpaper: %v", err)
	}
	t.Setenv("HOME", root)
	t.Setenv("XDG_STATE_HOME", filepath.Join(root, "state"))
	stateDir := filepath.Join(root, "state", "hypr-wallpaper", "monitors")
	if err := os.MkdirAll(stateDir, 0o755); err != nil {
		t.Fatalf("mkdir state: %v", err)
	}
	if err := os.WriteFile(filepath.Join(stateDir, "DP-3.state"), []byte("mode=static\npath="+wallpaper+"\n"), 0o644); err != nil {
		t.Fatalf("write state: %v", err)
	}

	var stdout, stderr bytes.Buffer
	if err := runWithIO([]string{"status", "--monitor", "DP-3"}, &stdout, &stderr); err != nil {
		t.Fatalf("runWithIO status --monitor error = %v stderr=%s", err, stderr.String())
	}
	for _, want := range []string{"monitor=DP-3", "mode=static", "path=" + wallpaper} {
		if !strings.Contains(stdout.String(), want) {
			t.Fatalf("stdout = %q, want %q", stdout.String(), want)
		}
	}
}

func TestWarmPageGeneratesVideoThumbnail(t *testing.T) {
	root := t.TempDir()
	bin := filepath.Join(root, "bin")
	writeExecutable(t, filepath.Join(bin, "ffmpeg"), "#!/bin/sh\nfor last do :; done\nmkdir -p \"$(dirname \"$last\")\"\nprintf x >\"$last\"\n")

	videoDir := filepath.Join(root, "Videos", "wallpapers")
	video := filepath.Join(videoDir, "new-video.mp4")
	if err := os.MkdirAll(videoDir, 0o755); err != nil {
		t.Fatalf("mkdir video dir: %v", err)
	}
	if err := os.WriteFile(video, []byte("video"), 0o600); err != nil {
		t.Fatalf("write video: %v", err)
	}

	stateDir := filepath.Join(root, "state", "hypr-wallpaper")
	if err := os.MkdirAll(stateDir, 0o755); err != nil {
		t.Fatalf("mkdir state dir: %v", err)
	}
	manifest := filepath.Join(stateDir, "wallpaper-picker.tsv")
	if err := os.WriteFile(manifest, []byte("video\t"+video+"\n"), 0o644); err != nil {
		t.Fatalf("write manifest: %v", err)
	}

	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))
	t.Setenv("HOME", root)
	t.Setenv("XDG_STATE_HOME", filepath.Join(root, "state"))
	t.Setenv("XDG_RUNTIME_DIR", filepath.Join(root, "runtime"))
	t.Setenv("HYPR_VIDEO_WALLPAPER_DIR", videoDir)

	var stdout, stderr bytes.Buffer
	if err := runWithIO([]string{"warm-page", "video", "0", "16"}, &stdout, &stderr); err != nil {
		t.Fatalf("runWithIO warm-page error = %v stderr=%s", err, stderr.String())
	}

	thumb := filepath.Join(videoDir, ".thumb", "new-video.mp4.jpg")
	if info, err := os.Stat(thumb); err != nil || info.Size() == 0 {
		t.Fatalf("thumb %s missing or empty: info=%v err=%v", thumb, info, err)
	}
}

func readFile(t *testing.T, path string) string {
	t.Helper()
	content, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read %s: %v", path, err)
	}
	return string(content)
}

func writeExecutable(t *testing.T, path, content string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatalf("mkdir parent: %v", err)
	}
	if err := os.WriteFile(path, []byte(content), 0o755); err != nil {
		t.Fatalf("write executable: %v", err)
	}
}
