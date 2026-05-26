package theme

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
)

const SchemaVersion = 1

var hexColor = regexp.MustCompile(`^#[0-9a-fA-F]{6}$`)

type Registry struct {
	SchemaVersion int     `json:"schemaVersion"`
	ActiveDefault string  `json:"activeDefault"`
	Themes        []Theme `json:"themes"`
}

type Theme struct {
	ID           string                       `json:"id"`
	Name         string                       `json:"name"`
	Description  string                       `json:"description,omitempty"`
	DefaultMode  string                       `json:"defaultMode"`
	Wallpaper    Wallpaper                    `json:"wallpaper,omitempty"`
	Palettes     map[string]Palette           `json:"palettes"`
	Targets      map[string]map[string]string `json:"targets,omitempty"`
	ReloadPolicy map[string]string            `json:"reloadPolicy,omitempty"`
	SafetyPolicy map[string]string            `json:"safetyPolicy,omitempty"`
}

type Wallpaper struct {
	Mode         string `json:"mode,omitempty"`
	Path         string `json:"path,omitempty"`
	DeriveColors bool   `json:"deriveColors"`
}

type Palette struct {
	Background string `json:"background"`
	Surface    string `json:"surface"`
	SurfaceAlt string `json:"surfaceAlt"`
	Foreground string `json:"foreground"`
	Muted      string `json:"muted"`
	Accent     string `json:"accent"`
	Accent2    string `json:"accent2"`
	Border     string `json:"border"`
	Urgent     string `json:"urgent"`
	Success    string `json:"success"`
}

type Summary struct {
	ID    string
	Name  string
	Modes []string
}

func LoadRegistry(path string) (Registry, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return Registry{}, err
	}
	var registry Registry
	if err := json.Unmarshal(data, &registry); err != nil {
		return Registry{}, err
	}
	if err := ValidateRegistry(registry); err != nil {
		return Registry{}, err
	}
	return registry, nil
}

func ValidateRegistry(registry Registry) error {
	if registry.SchemaVersion != SchemaVersion {
		return fmt.Errorf("schemaVersion must be %d", SchemaVersion)
	}
	if registry.ActiveDefault == "" {
		return fmt.Errorf("activeDefault is required")
	}
	if len(registry.Themes) == 0 {
		return fmt.Errorf("at least one theme is required")
	}
	seen := map[string]bool{}
	activeFound := false
	for _, theme := range registry.Themes {
		if theme.ID == "" {
			return fmt.Errorf("theme id is required")
		}
		if seen[theme.ID] {
			return fmt.Errorf("duplicate theme %q", theme.ID)
		}
		seen[theme.ID] = true
		if theme.ID == registry.ActiveDefault {
			activeFound = true
		}
		if theme.Name == "" {
			return fmt.Errorf("theme %q name is required", theme.ID)
		}
		if !validMode(theme.DefaultMode) {
			return fmt.Errorf("theme %q defaultMode must be dark, light, or auto", theme.ID)
		}
		for _, mode := range []string{"dark", "light"} {
			palette, ok := theme.Palettes[mode]
			if !ok {
				return fmt.Errorf("theme %q missing required palette %q", theme.ID, mode)
			}
			if err := validatePalette(theme.ID, mode, palette); err != nil {
				return err
			}
		}
	}
	if !activeFound {
		return fmt.Errorf("activeDefault %q does not match a theme", registry.ActiveDefault)
	}
	return nil
}

func Summaries(registry Registry) []Summary {
	summaries := make([]Summary, 0, len(registry.Themes))
	for _, theme := range registry.Themes {
		modes := make([]string, 0, len(theme.Palettes))
		for mode := range theme.Palettes {
			modes = append(modes, mode)
		}
		sort.Strings(modes)
		summaries = append(summaries, Summary{ID: theme.ID, Name: theme.Name, Modes: modes})
	}
	return summaries
}

func ActiveTheme(registry Registry) (Theme, bool) {
	for _, theme := range registry.Themes {
		if theme.ID == registry.ActiveDefault {
			return theme, true
		}
	}
	return Theme{}, false
}

func BuiltInNeutralTheme() Theme {
	return Theme{
		ID:          "neutral",
		Name:        "Neutral",
		Description: "Neutral theme derived from current Hyprland/Matugen palette.",
		DefaultMode: "dark",
		Wallpaper:   Wallpaper{Mode: "current", DeriveColors: false},
		Palettes: map[string]Palette{
			"dark": {
				Background: "#131317",
				Surface:    "#201f23",
				SurfaceAlt: "#353438",
				Foreground: "#e5e1e7",
				Muted:      "#918f9a",
				Accent:     "#c2c1ff",
				Accent2:    "#f5b2e0",
				Border:     "#47464f",
				Urgent:     "#ffb4ab",
				Success:    "#b5ccba",
			},
			"light": {
				Background: "#fffbff",
				Surface:    "#f4eff4",
				SurfaceAlt: "#e7e0e7",
				Foreground: "#1c1b1f",
				Muted:      "#767680",
				Accent:     "#595992",
				Accent2:    "#8a4f7b",
				Border:     "#c8c5d1",
				Urgent:     "#ba1a1a",
				Success:    "#386a20",
			},
		},
		Targets: map[string]map[string]string{
			"chromium": {"mode": "export"},
			"fuzzel":   {"mode": "generated"},
			"gtk":      {"mode": "generated"},
			"helix":    {"mode": "generated"},
			"hypr":     {"mode": "generated"},
			"kde":      {"mode": "generated"},
			"kitty":    {"mode": "generated"},
			"kvantum":  {"mode": "generated"},
			"nwg-dock": {"mode": "generated"},
			"qt":       {"mode": "generated"},
			"rofi":     {"mode": "generated"},
			"waybar":   {"mode": "generated"},
			"yazi":     {"mode": "generated"},
			"zen":      {"mode": "export"},
		},
		ReloadPolicy: map[string]string{
			"gtk":      "restart-hint",
			"hypr":     "hyprctl reload",
			"nwg-dock": "restart-hint",
			"qt":       "restart-hint",
			"waybar":   "SIGUSR2",
		},
		SafetyPolicy: map[string]string{"profileMutation": "disabled"},
	}
}

func UpsertNeutralTheme(registry Registry) Registry {
	neutral := BuiltInNeutralTheme()
	for i, existing := range registry.Themes {
		if existing.ID == neutral.ID {
			registry.Themes[i] = neutral
			return registry
		}
	}
	registry.Themes = append(registry.Themes, neutral)
	return registry
}

func SaveRegistryAtomic(path string, registry Registry) error {
	data, err := json.MarshalIndent(registry, "", "  ")
	if err != nil {
		return err
	}
	data = append(data, '\n')
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	tmp, err := os.CreateTemp(filepath.Dir(path), ".orgm-hypr-registry-*")
	if err != nil {
		return err
	}
	tmpPath := tmp.Name()
	defer os.Remove(tmpPath)
	if _, err := tmp.Write(data); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Sync(); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	if err := os.Chmod(tmpPath, 0o600); err != nil {
		return err
	}
	return os.Rename(tmpPath, path)
}

func validMode(mode string) bool {
	return mode == "dark" || mode == "light" || mode == "auto"
}

func validatePalette(themeID, mode string, palette Palette) error {
	colors := map[string]string{
		"background": palette.Background,
		"surface":    palette.Surface,
		"surfaceAlt": palette.SurfaceAlt,
		"foreground": palette.Foreground,
		"muted":      palette.Muted,
		"accent":     palette.Accent,
		"accent2":    palette.Accent2,
		"border":     palette.Border,
		"urgent":     palette.Urgent,
		"success":    palette.Success,
	}
	keys := []string{"background", "surface", "surfaceAlt", "foreground", "muted", "accent", "accent2", "border", "urgent", "success"}
	for _, key := range keys {
		if !hexColor.MatchString(colors[key]) {
			return fmt.Errorf("theme %q palette %q color %q must be #RRGGBB", themeID, mode, key)
		}
	}
	return nil
}
