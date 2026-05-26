package theme

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestLoadRegistryReadsValidNeutralTheme(t *testing.T) {
	path := writeRegistryFile(t, `{
		"schemaVersion": 1,
		"activeDefault": "neutral",
		"themes": [{
			"id": "neutral",
			"name": "Neutral",
			"description": "Current neutral desktop palette",
			"defaultMode": "dark",
			"wallpaper": {"mode": "current", "deriveColors": false},
			"palettes": {
				"dark": {"background": "#131317", "surface": "#201f23", "surfaceAlt": "#353438", "foreground": "#e5e1e7", "muted": "#918f9a", "accent": "#c2c1ff", "accent2": "#f5b2e0", "border": "#47464f", "urgent": "#ffb4ab", "success": "#b5ccba"},
				"light": {"background": "#fffbff", "surface": "#f4eff4", "surfaceAlt": "#e7e0e7", "foreground": "#1c1b1f", "muted": "#767680", "accent": "#595992", "accent2": "#8a4f7b", "border": "#c8c5d1", "urgent": "#ba1a1a", "success": "#386a20"}
			},
			"targets": {"chromium": {"mode": "export"}, "zen": {"mode": "export"}},
			"reloadPolicy": {"hypr": "manual"},
			"safetyPolicy": {"profileMutation": "disabled"}
		}]
	}`)

	registry, err := LoadRegistry(path)

	if err != nil {
		t.Fatalf("LoadRegistry() error = %v", err)
	}
	if got, want := registry.SchemaVersion, 1; got != want {
		t.Fatalf("SchemaVersion = %d, want %d", got, want)
	}
	neutral := registry.Themes[0]
	if got, want := neutral.ID, "neutral"; got != want {
		t.Fatalf("theme ID = %q, want %q", got, want)
	}
	if got, want := neutral.Palettes["dark"].Accent, "#c2c1ff"; got != want {
		t.Fatalf("dark accent = %q, want %q", got, want)
	}
	if got, want := neutral.Palettes["light"].Background, "#fffbff"; got != want {
		t.Fatalf("light background = %q, want %q", got, want)
	}
	if got, want := neutral.Targets["chromium"]["mode"], "export"; got != want {
		t.Fatalf("chromium mode = %q, want %q", got, want)
	}
}

func TestValidateRegistryRejectsMissingLightPalette(t *testing.T) {
	registry := Registry{
		SchemaVersion: 1,
		ActiveDefault: "neutral",
		Themes: []Theme{{
			ID: "neutral",
			Name: "Neutral",
			DefaultMode: "dark",
			Palettes: map[string]Palette{
				"dark": validPalette("#131317", "#e5e1e7", "#c2c1ff"),
			},
		}},
	}

	err := ValidateRegistry(registry)

	if err == nil {
		t.Fatal("ValidateRegistry() error = nil, want missing light palette error")
	}
	if got, want := err.Error(), `theme "neutral" missing required palette "light"`; !strings.Contains(got, want) {
		t.Fatalf("error = %q, want substring %q", got, want)
	}
}

func TestValidateRegistryRejectsInvalidColor(t *testing.T) {
	registry := Registry{
		SchemaVersion: 1,
		ActiveDefault: "neutral",
		Themes: []Theme{{
			ID: "neutral",
			Name: "Neutral",
			DefaultMode: "dark",
			Palettes: map[string]Palette{
				"dark": validPalette("131317", "#e5e1e7", "#c2c1ff"),
				"light": validPalette("#fffbff", "#1c1b1f", "#595992"),
			},
		}},
	}

	err := ValidateRegistry(registry)

	if err == nil {
		t.Fatal("ValidateRegistry() error = nil, want invalid color error")
	}
	if got, want := err.Error(), `theme "neutral" palette "dark" color "background" must be #RRGGBB`; !strings.Contains(got, want) {
		t.Fatalf("error = %q, want substring %q", got, want)
	}
}

func writeRegistryFile(t *testing.T, content string) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), "themes.json")
	if err := os.WriteFile(path, []byte(content), 0o600); err != nil {
		t.Fatalf("WriteFile() error = %v", err)
	}
	return path
}

func validPalette(background, foreground, accent string) Palette {
	return Palette{
		Background: background,
		Surface: "#201f23",
		SurfaceAlt: "#353438",
		Foreground: foreground,
		Muted: "#918f9a",
		Accent: accent,
		Accent2: "#f5b2e0",
		Border: "#47464f",
		Urgent: "#ffb4ab",
		Success: "#b5ccba",
	}
}
