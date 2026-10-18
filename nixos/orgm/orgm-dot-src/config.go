package main

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
)

type Context struct {
	Repository string   `json:"repository"`
	User       string   `json:"user"`
	Host       string   `json:"host"`
	Profile    string   `json:"profile"`
	Programs   []string `json:"programs"`
}

type Manifest struct {
	Version int      `json:"version"`
	Name    string   `json:"name"`
	Paths   []string `json:"paths"`
}

type Snapshot struct {
	Manifest
	Missing     []string `json:"missing"`
	Directories []string `json:"directories"`
}

type Runtime struct {
	Context
	Home, State string
	Apps        []Manifest
	Files       map[string]string
}

var identifier = regexp.MustCompile(`^[a-zA-Z0-9][a-zA-Z0-9_.-]*$`)

func readJSON(path string, value any) error {
	f, err := os.Open(path)
	if err != nil {
		return err
	}
	defer f.Close()
	d := json.NewDecoder(f)
	d.DisallowUnknownFields()
	if err := d.Decode(value); err != nil {
		return fmt.Errorf("%s: %w", path, err)
	}
	if err := d.Decode(new(any)); err != io.EOF {
		return fmt.Errorf("%s: trailing JSON", path)
	}
	return nil
}

func writeJSON(path string, value any) error {
	data, err := json.MarshalIndent(value, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, append(data, '\n'), 0600)
}

func validPath(path string) error {
	if path == "" || filepath.IsAbs(path) || filepath.Clean(path) != path || strings.Contains(path, "\\") {
		return fmt.Errorf("unsafe relative path: %q", path)
	}
	for _, part := range strings.Split(path, "/") {
		if part == ".." || part == "." || part == ".git" {
			return fmt.Errorf("unsafe path: %q", path)
		}
	}
	switch path {
	case ".config", ".local", ".local/bin", ".local/share", ".local/state", ".local/share/applications", ".local/share/icons", ".local/share/nautilus", ".local/share/nautilus/scripts", ".ssh", ".gnupg":
		return fmt.Errorf("shared or private root cannot be replaced: %s", path)
	}
	return nil
}

func contains(root, path string) bool { return path == root || strings.HasPrefix(path, root+"/") }

func metadata(name string) bool {
	switch name {
	case ".git", ".gitignore", ".DS_Store", "icon-theme.cache", "mimeinfo.cache", "__pycache__":
		return true
	}
	return strings.HasSuffix(name, ".bak") || strings.HasSuffix(name, "~") || strings.HasPrefix(name, "Icon\r")
}

// Same precedence as the former common-dotfiles module, evaluated at runtime.
// A Nix rebuild never imports, hashes or deploys these application files.
func (r *Runtime) collect() error {
	layers := []string{}
	for _, p := range r.Programs {
		layers = append(layers, "programs/"+p)
	}
	layers = append(layers, "profiles/"+r.Profile, "users/"+r.User+"/common")
	for _, p := range r.Programs {
		layers = append(layers, "users/"+r.User+"/programs/"+p)
	}
	layers = append(layers, "users/"+r.User+"/profiles/"+r.Profile, "hosts/"+r.Host+"/shared", "hosts/"+r.Host+"/profiles/"+r.Profile)
	r.Files = map[string]string{}
	for _, layer := range layers {
		root := filepath.Join(r.Repository, "dotfiles/config", layer)
		if _, err := os.Lstat(root); os.IsNotExist(err) {
			continue
		}
		if err := noLinkedParents(r.Repository, root, true); err != nil {
			return err
		}
		err := filepath.WalkDir(root, func(path string, entry os.DirEntry, err error) error {
			if err != nil {
				return err
			}
			if metadata(entry.Name()) {
				if entry.IsDir() {
					return filepath.SkipDir
				}
				return nil
			}
			if entry.IsDir() {
				return nil
			}
			rel, err := filepath.Rel(root, path)
			if err != nil {
				return err
			}
			if err := validPath(rel); err != nil {
				return err
			}
			if r.Profile == "ryoku" && (contains(".config/bash", rel) || rel == ".bashrc" || rel == ".blerc" || contains(".config/kitty", rel)) {
				if layer != "profiles/ryoku" {
					switch filepath.Base(rel) {
					case "functions.bash", "completions.bash", "fzf-widgets.bash", "sops-age.bash", "host-" + r.Host + ".bash":
						r.Files[".config/orgm-shell/"+filepath.Base(rel)] = path
					}
					return nil
				}
			} else if r.Profile == "ryoku" && !ryokuSelected(rel, layer) {
				return nil
			}
			r.Files[rel] = path
			return nil
		})
		if err != nil {
			return err
		}
	}
	// These personal workflows are shared without importing another desktop UI.
	if r.Profile == "ryoku" {
		for _, name := range []string{"hypr-obsidian-open-or-focus", "hypr-pi-prompt", "hypr-rofi-ssh-host"} {
			rel := ".local/bin/" + name
			path := filepath.Join(r.Repository, "dotfiles/config/users", r.User, "profiles/hyprland", rel)
			if info, err := os.Stat(path); err == nil && info.Mode().IsRegular() {
				r.Files[rel] = path
			}
		}
	}
	return nil
}

func ryokuSelected(path, layer string) bool {
	for _, root := range []string{".config/hypr", ".config/niri", ".config/quickshell", ".config/matugen", ".config/qt6ct", ".config/gtk-3.0", ".config/gtk-4.0", ".config/kitty", ".config/fish", ".config/wireplumber", ".config/yazi", ".config/pip", ".config/chromium-flags.conf", ".config/hyprland-preview-share-picker"} {
		if contains(root, path) {
			return false
		}
	}
	if path == ".bashrc" || path == ".blerc" || contains(".config/bash", path) {
		return false
	}
	if path == ".local/bin/orgm-visual-profile" || path == ".local/bin/openrgb-autostart" || path == ".local/bin/dunst_pause" {
		return false
	}
	if strings.HasSuffix(layer, "/common") && strings.HasPrefix(path, ".local/bin/") {
		switch filepath.Base(path) {
		case "bookmark_add", "bookmark_delete", "bookmark_to_type", "clipboard_copy", "hypr-video-timer":
			return true
		}
		return false
	}
	return true
}

func (r *Runtime) load() error {
	for _, value := range append([]string{r.User, r.Host, r.Profile}, r.Programs...) {
		if !identifier.MatchString(value) {
			return fmt.Errorf("invalid context identifier: %q", value)
		}
	}
	var err error
	r.Repository, err = filepath.Abs(r.Repository)
	if err != nil {
		return err
	}
	r.Home, err = filepath.Abs(r.Home)
	if err != nil {
		return err
	}
	if r.Repository == r.Home || r.Home == "/" {
		return fmt.Errorf("repository and home must be separate directories")
	}
	if r.State == "" {
		r.State = filepath.Join(r.Home, ".local/state/orgm-dot")
	}
	if r.State == r.Home || !contains(r.Home, r.State) {
		return fmt.Errorf("state must be a dedicated directory inside home")
	}
	if err := noLinkedParents(r.Repository, filepath.Join(r.Repository, "dotfiles/apps"), true); err != nil {
		return err
	}
	entries, err := os.ReadDir(filepath.Join(r.Repository, "dotfiles/apps"))
	if err != nil {
		return err
	}
	owners := map[string]string{}
	for _, entry := range entries {
		if !strings.HasSuffix(entry.Name(), ".json") {
			continue
		}
		if entry.Type()&os.ModeSymlink != 0 {
			return fmt.Errorf("manifest must be a regular file: %s", entry.Name())
		}
		var app Manifest
		if err := readJSON(filepath.Join(r.Repository, "dotfiles/apps", entry.Name()), &app); err != nil {
			return err
		}
		if app.Version != 1 || !identifier.MatchString(app.Name) || entry.Name() != app.Name+".json" || len(app.Paths) == 0 {
			return fmt.Errorf("invalid app manifest: %s", entry.Name())
		}
		for _, path := range app.Paths {
			if err := validPath(path); err != nil {
				return err
			}
			live := filepath.Join(r.Home, path)
			if contains(live, r.Repository) || contains(live, r.State) || contains(r.State, live) {
				return fmt.Errorf("managed path overlaps repository or helper state: %s", path)
			}
			for other, owner := range owners {
				if contains(other, path) || contains(path, other) {
					return fmt.Errorf("overlapping paths: %s (%s), %s (%s)", other, owner, path, app.Name)
				}
			}
			owners[path] = app.Name
		}
		r.Apps = append(r.Apps, app)
	}
	if err := r.collect(); err != nil {
		return err
	}
	for path := range r.Files {
		found := false
		for root := range owners {
			if contains(root, path) {
				found = true
				break
			}
		}
		if !found {
			return fmt.Errorf("configuration has no application manifest: %s", path)
		}
	}
	return nil
}

func (r Runtime) snapshot(app Manifest) string {
	return filepath.Join(r.Repository, "dotfiles/apps", app.Name, r.User, r.Host, r.Profile)
}

func (r Runtime) app(name string) (Manifest, error) {
	for _, app := range r.Apps {
		if app.Name == name {
			return app, nil
		}
	}
	return Manifest{}, fmt.Errorf("unknown application %q; use orgm-dot list", name)
}

func (r Runtime) activePaths(app Manifest) ([]string, error) {
	if err := noLinkedParents(r.Repository, r.snapshot(app), true); err != nil {
		return nil, err
	}
	var snapshot Snapshot
	err := readJSON(filepath.Join(r.snapshot(app), "snapshot.json"), &snapshot)
	if err == nil {
		if snapshot.Version != 1 || snapshot.Name != app.Name {
			return nil, fmt.Errorf("invalid snapshot for %s", app.Name)
		}
		for i, path := range snapshot.Paths {
			if err := validPath(path); err != nil {
				return nil, err
			}
			for _, other := range snapshot.Paths[:i] {
				if contains(path, other) || contains(other, path) {
					return nil, fmt.Errorf("overlapping snapshot paths")
				}
			}
			found := false
			for _, allowed := range app.Paths {
				if contains(allowed, path) {
					found = true
				}
			}
			if !found {
				return nil, fmt.Errorf("snapshot contains unregistered path: %s", path)
			}
		}
		return snapshot.Paths, nil
	}
	if !os.IsNotExist(err) {
		return nil, err
	}
	paths := []string{}
	for _, path := range app.Paths {
		for _, file := range sortedKeys(r.Files) {
			if contains(path, file) {
				if r.Profile == "ryoku" && (path == ".config/bash" || path == ".config/kitty") {
					paths = append(paths, file)
					continue
				}
				paths = append(paths, path)
				break
			}
		}
	}
	sort.Strings(paths)
	return paths, nil
}

// A new application only needs its JSON manifest to export an existing local
// configuration. No seed in config/ or Nix package declaration is required.
func (r Runtime) savePaths(app Manifest) ([]string, error) {
	paths, err := r.activePaths(app)
	if err != nil {
		return nil, err
	}
	for _, path := range app.Paths {
		// Ryoku's user imports are the boundary, not its native Bash/Kitty tree.
		if r.Profile == "ryoku" && (path == ".config/bash" || path == ".config/kitty") {
			continue
		}
		overlaps := false
		for _, selected := range paths {
			if contains(selected, path) || contains(path, selected) {
				overlaps = true
				break
			}
		}
		if overlaps {
			continue
		}
		if err := noLinkedParents(r.Home, filepath.Join(r.Home, path), false); err != nil {
			return nil, err
		}
		if present, err := exists(filepath.Join(r.Home, path)); err != nil {
			return nil, err
		} else if present {
			paths = append(paths, path)
		}
	}
	sort.Strings(paths)
	return paths, nil
}
