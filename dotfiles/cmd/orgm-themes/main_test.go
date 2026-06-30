package main

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestListPrintsAvailableThemes(t *testing.T) {
	root := t.TempDir()
	themesDir := filepath.Join(root, "config", "orgm-theme", "themes")
	writeCLITheme(t, themesDir, "orgm-light")
	writeCLITheme(t, themesDir, "orgm-dark")

	var stdout, stderr bytes.Buffer
	err := runWithIO([]string{"list"}, &stdout, &stderr, map[string]string{
		"HOME":            root,
		"XDG_CONFIG_HOME": filepath.Join(root, "config"),
		"XDG_STATE_HOME":  filepath.Join(root, "state"),
	})
	if err != nil {
		t.Fatalf("runWithIO list error = %v stderr=%s", err, stderr.String())
	}
	if got, want := stdout.String(), "orgm-dark\norgm-light\n"; got != want {
		t.Fatalf("stdout = %q, want %q", got, want)
	}
}

func TestCurrentPrintsCurrentTheme(t *testing.T) {
	root := t.TempDir()
	stateDir := filepath.Join(root, "state", "orgm-theme")
	if err := os.MkdirAll(stateDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(stateDir, "current"), []byte("orgm-light\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	var stdout, stderr bytes.Buffer
	err := runWithIO([]string{"current"}, &stdout, &stderr, map[string]string{
		"HOME":           root,
		"XDG_STATE_HOME": filepath.Join(root, "state"),
	})
	if err != nil {
		t.Fatalf("runWithIO current error = %v stderr=%s", err, stderr.String())
	}
	if got, want := stdout.String(), "orgm-light\n"; got != want {
		t.Fatalf("stdout = %q, want %q", got, want)
	}
}

func TestStatusPrintsCurrentThemeSettings(t *testing.T) {
	root := t.TempDir()
	configHome := filepath.Join(root, "config")
	stateHome := filepath.Join(root, "state")
	writeCLITheme(t, filepath.Join(configHome, "orgm-theme", "themes"), "orgm-light")
	stateDir := filepath.Join(stateHome, "orgm-theme")
	if err := os.MkdirAll(stateDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(stateDir, "current"), []byte("orgm-light\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	var stdout, stderr bytes.Buffer
	err := runWithIO([]string{"status"}, &stdout, &stderr, map[string]string{
		"HOME":            root,
		"XDG_CONFIG_HOME": configHome,
		"XDG_STATE_HOME":  stateHome,
	})
	if err != nil {
		t.Fatalf("runWithIO status error = %v stderr=%s", err, stderr.String())
	}
	for _, want := range []string{
		"Theme: orgm-light\n",
		"GTK: Adwaita\n",
		"Icons: Adwaita\n",
		"Cursor: Catppuccin-Latte-Teal-Cursors 36\n",
		"Color scheme: prefer-light\n",
		"Pi theme: orgm-light\n",
	} {
		if !strings.Contains(stdout.String(), want) {
			t.Fatalf("stdout = %q, want %q", stdout.String(), want)
		}
	}
}

func TestToggleAcceptsNoReloadAndWritesNextTheme(t *testing.T) {
	root := t.TempDir()
	configHome := filepath.Join(root, "config")
	stateHome := filepath.Join(root, "state")
	themesDir := filepath.Join(configHome, "orgm-theme", "themes")
	writeCLITheme(t, themesDir, "orgm-light")
	writeCLITheme(t, themesDir, "orgm-dark")
	stateDir := filepath.Join(stateHome, "orgm-theme")
	if err := os.MkdirAll(stateDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(stateDir, "current"), []byte("orgm-light\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	var stdout, stderr bytes.Buffer
	err := runWithIO([]string{"toggle", "--no-reload"}, &stdout, &stderr, map[string]string{
		"HOME":            root,
		"XDG_CONFIG_HOME": configHome,
		"XDG_STATE_HOME":  stateHome,
	})
	if err != nil {
		t.Fatalf("runWithIO toggle --no-reload error = %v stderr=%s", err, stderr.String())
	}
	if got, want := stdout.String(), "Applied orgm-dark\n"; got != want {
		t.Fatalf("stdout = %q, want %q", got, want)
	}
	current, err := os.ReadFile(filepath.Join(stateDir, "current"))
	if err != nil {
		t.Fatal(err)
	}
	if string(current) != "orgm-dark\n" {
		t.Fatalf("current = %q, want orgm-dark", current)
	}
	css, err := os.ReadFile(filepath.Join(configHome, "waybar-hypr", "orgm-current.css"))
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(css), "background-color: rgba(0, 0, 0, 0.6);") {
		t.Fatalf("waybar-hypr css missing dark background:\n%s", css)
	}
}

func TestMissingCommandReturnsUsageError(t *testing.T) {
	var stdout, stderr bytes.Buffer
	err := runWithIO(nil, &stdout, &stderr, map[string]string{"HOME": t.TempDir()})
	if err == nil {
		t.Fatal("runWithIO nil args succeeded, want usage error")
	}
	if !strings.Contains(err.Error(), "usage: orgm-themes") {
		t.Fatalf("error = %q, want usage", err.Error())
	}
}

func writeCLITheme(t *testing.T, themesDir, name string) {
	t.Helper()
	if err := os.MkdirAll(themesDir, 0o755); err != nil {
		t.Fatal(err)
	}
	colorScheme := "prefer-light"
	gtkTheme := "Adwaita"
	piTheme := "orgm-light"
	panelBG := "ffffffff"
	if name == "orgm-dark" {
		colorScheme = "prefer-dark"
		gtkTheme = "Adwaita-dark"
		piTheme = "orgm"
		panelBG = "00000099"
	}
	content := `THEME_NAME=` + name + `
COLOR_SCHEME=` + colorScheme + `
GTK_THEME=` + gtkTheme + `
ICON_THEME=Adwaita
CURSOR_THEME=Catppuccin-Latte-Teal-Cursors
CURSOR_SIZE=36
QT_STYLE=Fusion
PI_THEME=` + piTheme + `
KITTY_BACKGROUND_OPACITY=1.0
BASE=ffffff
MANTLE=f8fafc
CRUST=e5e7eb
TEXT=111827
SUBTEXT0=1f2937
SUBTEXT1=111827
SURFACE0=d1d5db
SURFACE1=9ca3af
SURFACE2=6b7280
OVERLAY0=374151
OVERLAY1=1f2937
OVERLAY2=111827
BLUE=0057d9
GREEN=40a02b
YELLOW=df8e1d
PEACH=fe640b
RED=d20f39
MAUVE=8839ef
PINK=ea76cb
TEAL=179299
SKY=04a5e5
ROSEWATER=dc8a78
PANEL_BG=` + panelBG + `
MENU_BG=ffffffff
QS_OVERLAY=ffffffff
QS_CARD=e5e7ebff
QS_CARD_STRONG=bfdbfeff
QS_CARD_SOFT=f8fafcff
QS_EVENT=ffffffff
QS_HOVER=93c5fdff
ON_ACCENT=ffffff
`
	if err := os.WriteFile(filepath.Join(themesDir, name+".env"), []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
}
