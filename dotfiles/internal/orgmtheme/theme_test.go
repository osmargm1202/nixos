package orgmtheme

import (
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

func writeTestTheme(t *testing.T, dir, name string) {
	t.Helper()
	if err := os.WriteFile(filepath.Join(dir, name+".env"), []byte(validThemeEnv(name)), 0o644); err != nil {
		t.Fatal(err)
	}
}

func validThemeEnv(name string) string {
	return `THEME_NAME=` + name + `
COLOR_SCHEME=prefer-light
GTK_THEME=Adwaita
ICON_THEME=Adwaita
CURSOR_THEME=Catppuccin-Latte-Teal-Cursors
CURSOR_SIZE=36
QT_STYLE=Fusion
PI_THEME=orgm-light
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
PANEL_BG=ffffffff
MENU_BG=ffffffff
QS_OVERLAY=ffffffff
QS_CARD=e5e7ebff
QS_CARD_STRONG=bfdbfeff
QS_CARD_SOFT=f8fafcff
QS_EVENT=ffffffff
QS_HOVER=93c5fdff
ON_ACCENT=ffffff
`
}

func TestLoadThemeEnv(t *testing.T) {
	dir := t.TempDir()
	writeTestTheme(t, dir, "orgm-light")
	theme, err := LoadTheme(dir, "orgm-light")
	if err != nil {
		t.Fatalf("LoadTheme error = %v", err)
	}
	if theme.Name != "orgm-light" || theme.Text != "111827" || theme.Blue != "0057d9" {
		t.Fatalf("theme = %#v", theme)
	}
}

func TestLoadThemeMissingRequiredKey(t *testing.T) {
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, "bad.env"), []byte("THEME_NAME=bad\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	_, err := LoadTheme(dir, "bad")
	if err == nil {
		t.Fatal("LoadTheme succeeded, want required key error")
	}
}

func TestLoadThemeRejectsInvalidNamesBeforeReading(t *testing.T) {
	root := t.TempDir()
	themesDir := filepath.Join(root, "themes")
	if err := os.MkdirAll(themesDir, 0o755); err != nil {
		t.Fatal(err)
	}
	writeTestTheme(t, root, "evil")
	if err := os.MkdirAll(filepath.Join(themesDir, "nested"), 0o755); err != nil {
		t.Fatal(err)
	}
	writeTestTheme(t, filepath.Join(themesDir, "nested"), "evil")
	if err := os.WriteFile(filepath.Join(themesDir, ".env"), []byte(validThemeEnv("empty-name")), 0o644); err != nil {
		t.Fatal(err)
	}

	for _, name := range []string{"", "../evil", "nested/evil", filepath.Join(root, "evil")} {
		_, err := LoadTheme(themesDir, name)
		if err == nil {
			t.Fatalf("LoadTheme(%q) succeeded, want invalid name error", name)
		}
		if !strings.Contains(err.Error(), "invalid theme name") {
			t.Fatalf("LoadTheme(%q) error = %v, want invalid theme name", name, err)
		}
	}
}

func TestListThemes(t *testing.T) {
	dir := t.TempDir()
	writeTestTheme(t, dir, "orgm-light")
	writeTestTheme(t, dir, "orgm-dark")
	if err := os.WriteFile(filepath.Join(dir, "notes.txt"), []byte("ignore"), 0o644); err != nil {
		t.Fatal(err)
	}

	themes, err := ListThemes(dir)
	if err != nil {
		t.Fatalf("ListThemes error = %v", err)
	}
	want := []string{"orgm-dark", "orgm-light"}
	if !reflect.DeepEqual(themes, want) {
		t.Fatalf("ListThemes = %#v, want %#v", themes, want)
	}
}
