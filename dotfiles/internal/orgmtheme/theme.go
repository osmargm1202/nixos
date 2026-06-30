package orgmtheme

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// Theme is one orgm-theme .env palette with desktop settings.
type Theme struct {
	Name                   string
	ColorScheme            string
	GTKTheme               string
	IconTheme              string
	CursorTheme            string
	CursorSize             string
	QTStyle                string
	PITheme                string
	KittyBackgroundOpacity string
	Base                   string
	Mantle                 string
	Crust                  string
	Text                   string
	Subtext0               string
	Subtext1               string
	Surface0               string
	Surface1               string
	Surface2               string
	Overlay0               string
	Overlay1               string
	Overlay2               string
	Blue                   string
	Green                  string
	Yellow                 string
	Peach                  string
	Red                    string
	Mauve                  string
	Pink                   string
	Teal                   string
	Sky                    string
	Rosewater              string
	PanelBG                string
	MenuBG                 string
	QSOverlay              string
	QSCard                 string
	QSCardStrong           string
	QSCardSoft             string
	QSEvent                string
	QSHover                string
	OnAccent               string
}

var requiredThemeKeys = []string{
	"THEME_NAME",
	"COLOR_SCHEME",
	"GTK_THEME",
	"ICON_THEME",
	"CURSOR_THEME",
	"CURSOR_SIZE",
	"QT_STYLE",
	"PI_THEME",
	"BASE",
	"MANTLE",
	"CRUST",
	"TEXT",
	"SUBTEXT0",
	"SUBTEXT1",
	"SURFACE0",
	"SURFACE1",
	"SURFACE2",
	"OVERLAY0",
	"OVERLAY1",
	"OVERLAY2",
	"BLUE",
	"GREEN",
	"YELLOW",
	"PEACH",
	"RED",
	"MAUVE",
	"PINK",
	"TEAL",
	"SKY",
	"ROSEWATER",
	"PANEL_BG",
	"MENU_BG",
	"QS_OVERLAY",
	"QS_CARD",
	"QS_CARD_STRONG",
	"QS_CARD_SOFT",
	"QS_EVENT",
	"QS_HOVER",
	"ON_ACCENT",
}

// LoadTheme reads themesDir/name.env and validates required keys.
func LoadTheme(themesDir, name string) (Theme, error) {
	if err := validateThemeName(name); err != nil {
		return Theme{}, err
	}
	values, err := readThemeEnv(filepath.Join(themesDir, name+".env"))
	if err != nil {
		return Theme{}, err
	}
	for _, key := range requiredThemeKeys {
		if values[key] == "" {
			return Theme{}, fmt.Errorf("theme %q missing required key %s", name, key)
		}
	}
	return Theme{
		Name:                   values["THEME_NAME"],
		ColorScheme:            values["COLOR_SCHEME"],
		GTKTheme:               values["GTK_THEME"],
		IconTheme:              values["ICON_THEME"],
		CursorTheme:            values["CURSOR_THEME"],
		CursorSize:             values["CURSOR_SIZE"],
		QTStyle:                values["QT_STYLE"],
		PITheme:                values["PI_THEME"],
		KittyBackgroundOpacity: values["KITTY_BACKGROUND_OPACITY"],
		Base:                   values["BASE"],
		Mantle:                 values["MANTLE"],
		Crust:                  values["CRUST"],
		Text:                   values["TEXT"],
		Subtext0:               values["SUBTEXT0"],
		Subtext1:               values["SUBTEXT1"],
		Surface0:               values["SURFACE0"],
		Surface1:               values["SURFACE1"],
		Surface2:               values["SURFACE2"],
		Overlay0:               values["OVERLAY0"],
		Overlay1:               values["OVERLAY1"],
		Overlay2:               values["OVERLAY2"],
		Blue:                   values["BLUE"],
		Green:                  values["GREEN"],
		Yellow:                 values["YELLOW"],
		Peach:                  values["PEACH"],
		Red:                    values["RED"],
		Mauve:                  values["MAUVE"],
		Pink:                   values["PINK"],
		Teal:                   values["TEAL"],
		Sky:                    values["SKY"],
		Rosewater:              values["ROSEWATER"],
		PanelBG:                values["PANEL_BG"],
		MenuBG:                 values["MENU_BG"],
		QSOverlay:              values["QS_OVERLAY"],
		QSCard:                 values["QS_CARD"],
		QSCardStrong:           values["QS_CARD_STRONG"],
		QSCardSoft:             values["QS_CARD_SOFT"],
		QSEvent:                values["QS_EVENT"],
		QSHover:                values["QS_HOVER"],
		OnAccent:               values["ON_ACCENT"],
	}, nil
}

// ListThemes returns sorted theme names from .env files in themesDir.
func ListThemes(themesDir string) ([]string, error) {
	entries, err := os.ReadDir(themesDir)
	if err != nil {
		return nil, err
	}
	var themes []string
	for _, entry := range entries {
		if entry.IsDir() || filepath.Ext(entry.Name()) != ".env" {
			continue
		}
		themes = append(themes, strings.TrimSuffix(entry.Name(), ".env"))
	}
	sort.Strings(themes)
	return themes, nil
}

func validateThemeName(name string) error {
	if name == "" {
		return fmt.Errorf("invalid theme name %q: name is empty", name)
	}
	if filepath.IsAbs(name) {
		return fmt.Errorf("invalid theme name %q: absolute paths are not allowed", name)
	}
	if name == "." || name == ".." || filepath.Clean(name) != name {
		return fmt.Errorf("invalid theme name %q: path traversal is not allowed", name)
	}
	if strings.ContainsRune(name, filepath.Separator) {
		return fmt.Errorf("invalid theme name %q: path separators are not allowed", name)
	}
	return nil
}

func readThemeEnv(path string) (map[string]string, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	values := make(map[string]string)
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		key, value, ok := strings.Cut(line, "=")
		if !ok {
			return nil, fmt.Errorf("invalid env line in %s: %q", path, line)
		}
		values[strings.TrimSpace(key)] = strings.TrimPrefix(strings.TrimSpace(value), "#")
	}
	if err := scanner.Err(); err != nil {
		return nil, err
	}
	return values, nil
}
