package wallpaper

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/osmargm1202/nixos/internal/paths"
)

// PickerItem is one wallpaper entry consumed by Quickshell.
type PickerItem struct {
	Name  string `json:"name"`
	Path  string `json:"path"`
	Thumb string `json:"thumb"`
}

// PickerMonitor is one Hyprland output target consumed by Quickshell.
type PickerMonitor struct {
	Name        string `json:"name"`
	Description string `json:"description,omitempty"`
}

// PickerData is the JSON schema consumed by the resident Quickshell picker.
type PickerData struct {
	Mode         string       `json:"mode"`
	Title        string       `json:"title"`
	ApplyCommand string       `json:"applyCommand"`
	Script       string       `json:"script"`
	ScriptArgs   []string     `json:"scriptArgs,omitempty"`
	Current      string       `json:"current"`
	Items        []PickerItem `json:"items"`
}

// PickerTab is one tab inside the combined Quickshell picker schema.
type PickerTab struct {
	Title         string       `json:"title"`
	ApplyCommand  string       `json:"applyCommand"`
	RandomCommand string       `json:"randomCommand"`
	Current       string       `json:"current"`
	Items         []PickerItem `json:"items"`
}

// CombinedPickerData is the JSON schema consumed by the unified Quickshell picker.
type CombinedPickerData struct {
	Mode        string               `json:"mode"`
	InitialMode string               `json:"initialMode"`
	Script      string               `json:"script"`
	ScriptArgs  []string             `json:"scriptArgs,omitempty"`
	Monitors    []PickerMonitor      `json:"monitors,omitempty"`
	Tabs        map[string]PickerTab `json:"tabs"`
}

// CombinedDataOptions configures combined Quickshell picker JSON generation.
type CombinedDataOptions struct {
	ManifestPath string
	JSONPath     string
	InitialMode  string
	CurrentMode  string
	CurrentPath  string
	Script       string
	ScriptArgs   []string
	Monitors     []PickerMonitor
}

// DataOptions configures Quickshell picker JSON generation.
type DataOptions struct {
	Mode         string
	ManifestPath string
	JSONPath     string
	CurrentPath  string
	Script       string
	ScriptArgs   []string
}

func (o DataOptions) validate() error {
	switch o.Mode {
	case "static", "video":
	default:
		return fmt.Errorf("mode must be static or video")
	}
	if o.ManifestPath == "" {
		return fmt.Errorf("manifest path is required")
	}
	if o.JSONPath == "" {
		return fmt.Errorf("json path is required")
	}
	return nil
}

func (o CombinedDataOptions) validate() error {
	if o.ManifestPath == "" {
		return fmt.Errorf("manifest path is required")
	}
	if o.JSONPath == "" {
		return fmt.Errorf("json path is required")
	}
	if o.InitialMode != "" {
		switch o.InitialMode {
		case "static", "video":
		default:
			return fmt.Errorf("initial mode must be static or video")
		}
	}
	return nil
}

// GeneratePickerData reads a TSV manifest and writes Quickshell picker JSON.
// Manifest rows are `<mode>\t<absolute path>`, matching hypr-random-wallpaper.
func GeneratePickerData(opts DataOptions) error {
	if err := opts.validate(); err != nil {
		return err
	}

	manifest, err := os.Open(opts.ManifestPath)
	if err != nil {
		return err
	}
	defer manifest.Close()

	data, err := BuildPickerData(opts, manifest)
	if err != nil {
		return err
	}

	output, err := os.Create(opts.JSONPath)
	if err != nil {
		return err
	}
	defer output.Close()

	encoder := json.NewEncoder(output)
	encoder.SetEscapeHTML(false)
	encoder.SetIndent("", "  ")
	if err := encoder.Encode(data); err != nil {
		return err
	}
	return output.Close()
}

// GenerateCombinedPickerData reads a TSV manifest and writes combined Quickshell picker JSON.
func GenerateCombinedPickerData(opts CombinedDataOptions) error {
	if err := opts.validate(); err != nil {
		return err
	}

	manifest, err := os.Open(opts.ManifestPath)
	if err != nil {
		return err
	}
	defer manifest.Close()

	data, err := BuildCombinedPickerData(opts, manifest)
	if err != nil {
		return err
	}

	output, err := os.Create(opts.JSONPath)
	if err != nil {
		return err
	}
	defer output.Close()

	encoder := json.NewEncoder(output)
	encoder.SetEscapeHTML(false)
	encoder.SetIndent("", "  ")
	if err := encoder.Encode(data); err != nil {
		return err
	}
	return output.Close()
}

// BuildPickerData converts a manifest reader into the Quickshell schema.
func BuildPickerData(opts DataOptions, manifest io.Reader) (PickerData, error) {
	if err := opts.validate(); err != nil {
		return PickerData{}, err
	}

	data := PickerData{
		Mode:         opts.Mode,
		Title:        titleForMode(opts.Mode),
		ApplyCommand: applyCommandForMode(opts.Mode),
		Script:       opts.Script,
		ScriptArgs:   opts.ScriptArgs,
		Current:      opts.CurrentPath,
		Items:        []PickerItem{},
	}
	if data.Script == "" {
		data.Script = "orgm-wallpaper"
	}

	scanner := bufio.NewScanner(manifest)
	for scanner.Scan() {
		line := strings.TrimSuffix(scanner.Text(), "\n")
		if line == "" {
			continue
		}
		rowMode, wallpaperPath, ok := strings.Cut(line, "\t")
		if !ok {
			return PickerData{}, fmt.Errorf("invalid manifest row: %q", line)
		}
		if rowMode != opts.Mode {
			continue
		}
		data.Items = append(data.Items, PickerItem{
			Name:  filepath.Base(wallpaperPath),
			Path:  wallpaperPath,
			Thumb: paths.ThumbPath(wallpaperPath),
		})
	}
	if err := scanner.Err(); err != nil {
		return PickerData{}, err
	}

	return data, nil
}

// BuildCombinedPickerData converts a manifest reader into the unified Quickshell schema.
func BuildCombinedPickerData(opts CombinedDataOptions, manifest io.Reader) (CombinedPickerData, error) {
	if err := opts.validate(); err != nil {
		return CombinedPickerData{}, err
	}

	initialMode := opts.InitialMode
	if initialMode == "" {
		initialMode = normalizedPickerMode(opts.CurrentMode)
	}
	if initialMode == "" {
		initialMode = "static"
	}

	data := CombinedPickerData{
		Mode:        "combined",
		InitialMode: initialMode,
		Script:      opts.Script,
		ScriptArgs:  opts.ScriptArgs,
		Monitors:    opts.Monitors,
		Tabs: map[string]PickerTab{
			"static": {
				Title:         titleForMode("static"),
				ApplyCommand:  applyCommandForMode("static"),
				RandomCommand: randomCommandForMode("static"),
				Items:         []PickerItem{},
			},
			"video": {
				Title:         titleForMode("video"),
				ApplyCommand:  applyCommandForMode("video"),
				RandomCommand: randomCommandForMode("video"),
				Items:         []PickerItem{},
			},
		},
	}
	if data.Script == "" {
		data.Script = "orgm-wallpaper"
	}

	currentMode := normalizedPickerMode(opts.CurrentMode)
	if currentMode != "" && opts.CurrentPath != "" {
		tab := data.Tabs[currentMode]
		tab.Current = opts.CurrentPath
		data.Tabs[currentMode] = tab
	}

	scanner := bufio.NewScanner(manifest)
	for scanner.Scan() {
		line := strings.TrimSuffix(scanner.Text(), "\n")
		if line == "" {
			continue
		}
		rowMode, wallpaperPath, ok := strings.Cut(line, "\t")
		if !ok {
			return CombinedPickerData{}, fmt.Errorf("invalid manifest row: %q", line)
		}
		mode := normalizedPickerMode(rowMode)
		tab, ok := data.Tabs[mode]
		if !ok {
			continue
		}
		tab.Items = append(tab.Items, PickerItem{
			Name:  filepath.Base(wallpaperPath),
			Path:  wallpaperPath,
			Thumb: paths.ThumbPath(wallpaperPath),
		})
		data.Tabs[mode] = tab
	}
	if err := scanner.Err(); err != nil {
		return CombinedPickerData{}, err
	}

	return data, nil
}

func titleForMode(mode string) string {
	if mode == "video" {
		return "Live wallpapers"
	}
	return "Normal wallpapers"
}

func applyCommandForMode(mode string) string {
	if mode == "video" {
		return "set-video"
	}
	return "set-static"
}

func randomCommandForMode(mode string) string {
	if mode == "video" {
		return "random-video"
	}
	return "random-static"
}

func normalizedPickerMode(mode string) string {
	switch mode {
	case "video":
		return "video"
	case "static", "static-random":
		return "static"
	default:
		return ""
	}
}
