package main

import (
	"fmt"
	"os"
	"path/filepath"
)

type removedApp struct {
	Version int    `json:"version"`
	Name    string `json:"name"`
}

func (r Runtime) disabled(app Manifest) (bool, error) {
	root := r.snapshot(app)
	if err := noLinkedParents(r.Repository, root, true); err != nil {
		return false, err
	}
	var record removedApp
	err := readJSON(filepath.Join(root, "removed.json"), &record)
	if os.IsNotExist(err) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	if record.Version != 1 || record.Name != app.Name {
		return false, fmt.Errorf("invalid removal record for %s", app.Name)
	}
	return true, nil
}

// The registry remains shared across hosts. Removing an app replaces only its
// current context snapshot with a tombstone, so bootstrap cannot reintroduce it.
func (r Runtime) remove(app Manifest) (string, error) {
	if removed, err := r.disabled(app); err != nil {
		return "", err
	} else if removed {
		return "", fmt.Errorf("%s is already removed in this context", app.Name)
	}
	tmp, err := os.MkdirTemp("", "orgm-dot-remove-")
	if err != nil {
		return "", err
	}
	defer os.RemoveAll(tmp)
	if err := os.Mkdir(filepath.Join(tmp, r.Profile), 0700); err != nil {
		return "", err
	}
	if err := writeJSON(filepath.Join(tmp, r.Profile, "removed.json"), removedApp{1, app.Name}); err != nil {
		return "", err
	}
	return r.replace(app, "remove", tmp, filepath.Dir(r.snapshot(app)), []string{r.Profile})
}

func (r Runtime) add(app Manifest, dry bool) error {
	if !identifier.MatchString(app.Name) || len(app.Paths) == 0 {
		return fmt.Errorf("specify an application name and at least one HOME-relative path")
	}
	if _, err := r.app(app.Name); err == nil {
		return fmt.Errorf("%s already has a manifest; use orgm-dot show %s", app.Name, app.Name)
	}
	for i, path := range app.Paths {
		if err := validPath(path); err != nil {
			return err
		}
		live := filepath.Join(r.Home, path)
		if contains(live, r.Repository) || contains(live, r.State) || contains(r.State, live) {
			return fmt.Errorf("managed path overlaps repository or helper state: %s", path)
		}
		for _, other := range app.Paths[:i] {
			if contains(other, path) || contains(path, other) {
				return fmt.Errorf("overlapping paths: %s, %s", other, path)
			}
		}
		for _, registered := range r.Apps {
			for _, other := range registered.Paths {
				if contains(other, path) || contains(path, other) {
					return fmt.Errorf("path %s overlaps %s (%s)", path, other, registered.Name)
				}
			}
		}
	}
	if dry {
		fmt.Printf("Registrar %s: %v; no copiar archivos.\n", app.Name, app.Paths)
		return nil
	}
	manifest := filepath.Join(r.Repository, "dotfiles/apps", app.Name+".json")
	if _, err := os.Lstat(manifest); err == nil {
		return fmt.Errorf("manifest already exists: %s", manifest)
	} else if !os.IsNotExist(err) {
		return err
	}
	if err := atomicJSON(manifest, app); err != nil {
		return err
	}
	fmt.Printf("Registrado %s: %s\nGuardar la configuración: orgm-dot push %s\n", app.Name, manifest, app.Name)
	return nil
}
