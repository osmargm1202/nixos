package main

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"syscall"
	"time"
)

type Backup struct {
	Version   int      `json:"version"`
	App       string   `json:"app"`
	Direction string   `json:"direction"`
	Root      string   `json:"root"`
	User      string   `json:"user"`
	Host      string   `json:"host"`
	Profile   string   `json:"profile"`
	Paths     []string `json:"paths"`
}

var renamePath = os.Rename

func sortedKeys[V any](m map[string]V) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}

func (r Runtime) lock() (func(), error) {
	if err := noLinkedParents(r.Home, r.State, true); err != nil {
		return nil, err
	}
	if err := os.MkdirAll(r.State, 0700); err != nil {
		return nil, err
	}
	// Lock the repository too: two hosts/users sharing a checkout must not race.
	files := []*os.File{}
	unlock := func() {
		for _, f := range files {
			syscall.Flock(int(f.Fd()), syscall.LOCK_UN)
			f.Close()
		}
	}
	for _, path := range []string{filepath.Join(r.State, "sync.lock"), filepath.Join(r.Repository, ".orgm-dot.lock")} {
		fd, err := syscall.Open(path, syscall.O_CREAT|syscall.O_RDWR|syscall.O_NOFOLLOW, 0600)
		if err != nil {
			unlock()
			return nil, err
		}
		f := os.NewFile(uintptr(fd), path)
		files = append(files, f)
		if err := syscall.Flock(fd, syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
			unlock()
			return nil, fmt.Errorf("another orgm-dot operation is running: %s", path)
		}
	}
	return unlock, nil
}

// Preflight and stage every path before touching any destination. Renames are
// atomic per path; if a later rename fails, restore all earlier paths.
func (r Runtime) replace(app Manifest, direction, srcRoot, dstRoot string, paths []string) (string, error) {
	if len(paths) == 0 {
		return "", fmt.Errorf("no paths selected for %s in %s/%s/%s", app.Name, r.User, r.Host, r.Profile)
	}
	for _, path := range paths {
		if err := validPath(path); err != nil {
			return "", err
		}
		if err := noLinkedParents(dstRoot, filepath.Join(dstRoot, path), false); err != nil {
			return "", err
		}
		if err := noLinkedParents(srcRoot, filepath.Join(srcRoot, path), false); err != nil {
			return "", err
		}
	}
	id := time.Now().UTC().Format("20060102T150405.000000000") + "-" + app.Name + "-" + direction
	backup := filepath.Join(r.State, "backups", id)
	if err := noLinkedParents(r.State, backup, true); err != nil {
		return "", err
	}
	if err := os.MkdirAll(backup, 0700); err != nil {
		return "", err
	}
	meta := Backup{1, app.Name, direction, dstRoot, r.User, r.Host, r.Profile, paths}
	type staged struct {
		dst, dir       string
		had, installed bool
	}
	items := []staged{}
	defer func() {
		for _, item := range items {
			os.RemoveAll(item.dir)
		}
	}()
	for i, path := range paths {
		dst := filepath.Join(dstRoot, path)
		had, err := exists(dst)
		if err != nil {
			return "", err
		}
		if had {
			if err := copyTree(dst, filepath.Join(backup, fmt.Sprint(i)), dst, filepath.Join(backup, fmt.Sprint(i)), 0); err != nil {
				return "", err
			}
		}
		if err := os.MkdirAll(filepath.Dir(dst), 0700); err != nil {
			return "", err
		}
		dir, err := os.MkdirTemp(filepath.Dir(dst), ".orgm-dot-stage-")
		if err != nil {
			return "", err
		}
		items = append(items, staged{dst: dst, dir: dir, had: had})
		src := filepath.Join(srcRoot, path)
		if present, err := exists(src); err != nil {
			return "", err
		} else if present {
			if err := copyTree(src, filepath.Join(dir, "new"), src, filepath.Join(dir, "new"), 0); err != nil {
				return "", err
			}
		}
	}
	if err := writeJSON(filepath.Join(backup, "backup.json"), meta); err != nil {
		return "", err
	}
	rollback := func(cause error) error {
		for i := len(items) - 1; i >= 0; i-- {
			item := items[i]
			if item.installed {
				if err := os.RemoveAll(item.dst); err != nil {
					return fmt.Errorf("%v; rollback failed, backup %s: %w", cause, id, err)
				}
			}
			if present, _ := exists(filepath.Join(item.dir, "old")); present {
				if err := renamePath(filepath.Join(item.dir, "old"), item.dst); err != nil {
					return fmt.Errorf("%v; rollback failed, backup %s: %w", cause, id, err)
				}
			}
		}
		return cause
	}
	for i := range items {
		item := &items[i]
		if item.had {
			if err := renamePath(item.dst, filepath.Join(item.dir, "old")); err != nil {
				return "", rollback(err)
			}
		}
		if present, _ := exists(filepath.Join(item.dir, "new")); present {
			if err := renamePath(filepath.Join(item.dir, "new"), item.dst); err != nil {
				return "", rollback(err)
			}
			item.installed = true
		}
	}
	return id, nil
}

func (r Runtime) apply(app Manifest) (string, error) {
	src, paths, err := r.prepared(app)
	if err != nil {
		return "", err
	}
	defer os.RemoveAll(src)
	return r.replace(app, "pull", src, r.Home, paths)
}

func (r Runtime) save(app Manifest) (string, error) {
	paths, err := r.savePaths(app)
	if err != nil {
		return "", err
	}
	if len(paths) == 0 {
		return "", fmt.Errorf("application %s is not selected in this context", app.Name)
	}
	tmp, err := os.MkdirTemp("", "orgm-dot-save-")
	if err != nil {
		return "", err
	}
	defer os.RemoveAll(tmp)
	record := Snapshot{Manifest: Manifest{1, app.Name, paths}, Missing: []string{}, Directories: []string{}}
	for _, path := range paths {
		src := filepath.Join(r.Home, path)
		if err := noLinkedParents(r.Home, src, false); err != nil {
			return "", err
		}
		if present, err := exists(src); err != nil {
			return "", err
		} else if present {
			if err := copyTree(src, filepath.Join(tmp, "snapshot/home", path), src, filepath.Join(tmp, "snapshot/home", path), 0); err != nil {
				return "", err
			}
		} else {
			record.Missing = append(record.Missing, path)
		}
	}
	files, err := inventory(filepath.Join(tmp, "snapshot/home"), paths)
	if err != nil {
		return "", err
	}
	for _, path := range sortedKeys(files) {
		if files[path].Kind == "directory" {
			record.Directories = append(record.Directories, path)
		}
	}
	if err := os.MkdirAll(filepath.Join(tmp, "snapshot"), 0700); err != nil {
		return "", err
	}
	if err := writeJSON(filepath.Join(tmp, "snapshot/snapshot.json"), record); err != nil {
		return "", err
	}
	// The whole per-context app snapshot is replaced, including deletions.
	dst := r.snapshot(app)
	if err := noLinkedParents(r.Repository, dst, false); err != nil {
		return "", err
	}
	if err := os.Rename(filepath.Join(tmp, "snapshot"), filepath.Join(tmp, r.Profile)); err != nil {
		return "", err
	}
	return r.replace(app, "push", tmp, filepath.Dir(dst), []string{filepath.Base(dst)})
}

func (r Runtime) restore(id string) (string, error) {
	if filepath.Base(id) != id || id == "." || id == ".." {
		return "", fmt.Errorf("invalid backup identifier")
	}
	base := filepath.Join(r.State, "backups", id)
	if err := noLinkedParents(r.State, base, true); err != nil {
		return "", err
	}
	var meta Backup
	if err := readJSON(filepath.Join(base, "backup.json"), &meta); err != nil {
		return "", err
	}
	app, err := r.app(meta.App)
	if err != nil {
		return "", err
	}
	if meta.Version != 1 || meta.User != r.User || meta.Host != r.Host || meta.Profile != r.Profile {
		return "", fmt.Errorf("backup belongs to a different context")
	}
	expected := r.Home
	if meta.Direction == "push" || meta.Direction == "remove" {
		expected = filepath.Dir(r.snapshot(app))
		if len(meta.Paths) != 1 || meta.Paths[0] != r.Profile {
			return "", fmt.Errorf("invalid push backup paths")
		}
	} else {
		for _, path := range meta.Paths {
			allowed := false
			for _, p := range app.Paths {
				if contains(p, path) {
					allowed = true
				}
			}
			if !allowed {
				return "", fmt.Errorf("unregistered backup path: %s", path)
			}
		}
	}
	if meta.Root != expected {
		return "", fmt.Errorf("backup destination changed")
	}
	tmp, err := os.MkdirTemp("", "orgm-dot-restore-")
	if err != nil {
		return "", err
	}
	defer os.RemoveAll(tmp)
	for i, path := range meta.Paths {
		src := filepath.Join(base, fmt.Sprint(i))
		if present, err := exists(src); err != nil {
			return "", err
		} else if present {
			if err := copyTree(src, filepath.Join(tmp, path), src, filepath.Join(tmp, path), 0); err != nil {
				return "", err
			}
		}
	}
	return r.replace(app, meta.Direction, tmp, meta.Root, meta.Paths)
}
