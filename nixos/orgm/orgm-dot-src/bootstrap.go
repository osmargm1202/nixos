package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// A rebuild only seeds a context once. Explicit pull is the only operation
// that subsequently replaces complete application directories.
func (r Runtime) bootstrap() error {
	key := r.User + "-" + r.Host + "-" + r.Profile
	marker := filepath.Join(r.State, "bootstrap-"+key+".json")
	completed := map[string]bool{}
	if err := readJSON(marker, &completed); err != nil && !os.IsNotExist(err) {
		return err
	}
	for _, app := range r.Apps {
		if disabled, err := r.disabled(app); err != nil {
			return err
		} else if disabled {
			continue
		}
		if completed[app.Name] {
			continue
		}
		src, paths, err := r.prepared(app)
		if err != nil {
			return err
		}
		if len(paths) == 0 {
			os.RemoveAll(src)
			continue
		}
		// Withdraw registered old whole-directory Home Manager links first.
		for _, path := range paths {
			dst := filepath.Join(r.Home, path)
			if info, err := os.Lstat(dst); err == nil && info.Mode()&os.ModeSymlink != 0 {
				resolved, err := filepath.EvalSymlinks(dst)
				if err == nil && strings.HasPrefix(resolved, "/nix/store/") {
					if ri, err := os.Stat(resolved); err == nil && ri.IsDir() {
						tmp, err := os.MkdirTemp("", "orgm-dot-legacy-")
						if err != nil {
							os.RemoveAll(src)
							return err
						}
						err = copyTree(resolved, filepath.Join(tmp, path), resolved, filepath.Join(tmp, path), 0)
						if err == nil {
							_, err = r.replace(app, "bootstrap", tmp, r.Home, []string{path})
						}
						os.RemoveAll(tmp)
						if err != nil {
							os.RemoveAll(src)
							return err
						}
					}
				}
			}
		}
		var pending []string
		files, err := inventory(src, paths)
		if err != nil {
			os.RemoveAll(src)
			return err
		}
		for _, path := range sortedKeys(files) {
			if files[path].Kind == "directory" {
				continue
			}
			dst := filepath.Join(r.Home, path)
			if err := noLinkedParents(r.Home, dst, false); err != nil {
				os.RemoveAll(src)
				return err
			}
			info, err := os.Lstat(dst)
			if os.IsNotExist(err) {
				pending = append(pending, path)
				continue
			}
			if err != nil {
				os.RemoveAll(src)
				return err
			}
			if info.Mode()&os.ModeSymlink != 0 {
				link, err := os.Readlink(dst)
				if err != nil {
					os.RemoveAll(src)
					return err
				}
				resolved, _ := filepath.EvalSymlinks(dst)
				if strings.HasPrefix(link, "/nix/store/") || strings.HasPrefix(resolved, "/nix/store/") {
					pending = append(pending, path)
				}
			}
		}
		if len(pending) > 0 {
			if id, err := r.replace(app, "bootstrap", src, r.Home, pending); err != nil {
				os.RemoveAll(src)
				return err
			} else {
				fmt.Printf("%s: copied %d paths; backup %s\n", app.Name, len(pending), id)
			}
		}
		os.RemoveAll(src)
		completed[app.Name] = true
		if err := atomicJSON(marker, completed); err != nil {
			return err
		}
	}
	return nil
}

func atomicJSON(path string, value any) error {
	f, err := os.CreateTemp(filepath.Dir(path), ".orgm-dot-json-")
	if err != nil {
		return err
	}
	tmp := f.Name()
	f.Close()
	defer os.Remove(tmp)
	if err := writeJSON(tmp, value); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}
