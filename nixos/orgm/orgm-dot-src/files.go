package main

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

// Refuse directory symlinks at the boundary as well as inside it. The final
// component may be replaced, but never opened through when writing.
func noLinkedParents(root, target string, includeTarget bool) error {
	rel, err := filepath.Rel(root, target)
	if err != nil || rel == ".." || strings.HasPrefix(rel, "../") {
		return fmt.Errorf("path escapes root: %s", target)
	}
	if !includeTarget {
		rel = filepath.Dir(rel)
	}
	current := filepath.Clean(root)
	parts := []string{current}
	if rel != "." {
		for _, part := range strings.Split(rel, string(filepath.Separator)) {
			current = filepath.Join(current, part)
			parts = append(parts, current)
		}
	}
	for _, path := range parts {
		info, err := os.Lstat(path)
		if os.IsNotExist(err) {
			continue
		}
		if err != nil {
			return err
		}
		if info.Mode()&os.ModeSymlink != 0 {
			return fmt.Errorf("directory symlink must be materialized first: %s", path)
		}
		if !info.IsDir() {
			return fmt.Errorf("parent is not a directory: %s", path)
		}
	}
	return nil
}

func exists(path string) (bool, error) {
	_, err := os.Lstat(path)
	if os.IsNotExist(err) {
		return false, nil
	}
	return err == nil, err
}

// Copy data, making store files writable. Keep only relative links confined to
// the copied tree. Legacy Home Manager store links are materialized as data.
func copyTree(src, dst, srcRoot, dstRoot string, depth int) error {
	if depth > 64 {
		return fmt.Errorf("symlink cycle or excessive nesting: %s", src)
	}
	info, err := os.Lstat(src)
	if err != nil {
		return err
	}
	if info.Mode()&os.ModeSymlink != 0 {
		link, err := os.Readlink(src)
		if err != nil {
			return err
		}
		resolved, err := filepath.EvalSymlinks(src)
		if err != nil {
			return err
		}
		if strings.HasPrefix(resolved, "/nix/store/") {
			return copyTree(resolved, dst, resolved, dst, depth+1)
		}
		if filepath.IsAbs(link) {
			return fmt.Errorf("external absolute symlink: %s", src)
		}
		rel, err := filepath.Rel(srcRoot, resolved)
		if err != nil || rel == ".." || strings.HasPrefix(rel, "../") {
			return fmt.Errorf("symlink escapes copied tree: %s", src)
		}
		if err := os.MkdirAll(filepath.Dir(dst), 0700); err != nil {
			return err
		}
		return os.Symlink(link, dst)
	}
	if info.IsDir() {
		if err := os.MkdirAll(dst, info.Mode().Perm()|0700); err != nil {
			return err
		}
		entries, err := os.ReadDir(src)
		if err != nil {
			return err
		}
		for _, entry := range entries {
			if err := copyTree(filepath.Join(src, entry.Name()), filepath.Join(dst, entry.Name()), srcRoot, dstRoot, depth+1); err != nil {
				return err
			}
		}
		return nil
	}
	if !info.Mode().IsRegular() {
		return fmt.Errorf("special file cannot be synchronized: %s", src)
	}
	if err := os.MkdirAll(filepath.Dir(dst), 0700); err != nil {
		return err
	}
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()
	out, err := os.OpenFile(dst, os.O_WRONLY|os.O_CREATE|os.O_EXCL, info.Mode().Perm()|0200)
	if err != nil {
		return err
	}
	_, copyErr := io.Copy(out, in)
	closeErr := out.Close()
	if copyErr != nil {
		return copyErr
	}
	return closeErr
}

func (r Runtime) prepared(app Manifest) (string, []string, error) {
	paths, err := r.activePaths(app)
	if err != nil {
		return "", nil, err
	}
	tmp, err := os.MkdirTemp("", "orgm-dot-source-")
	if err != nil {
		return "", nil, err
	}
	ok := false
	defer func() {
		if !ok {
			os.RemoveAll(tmp)
		}
	}()
	if _, err := os.Stat(filepath.Join(r.snapshot(app), "snapshot.json")); err == nil {
		var record Snapshot
		if err := readJSON(filepath.Join(r.snapshot(app), "snapshot.json"), &record); err != nil {
			return "", nil, err
		}
		missing := map[string]bool{}
		for _, path := range record.Missing {
			found := false
			for _, p := range paths {
				if p == path {
					found = true
				}
			}
			if !found || missing[path] {
				return "", nil, fmt.Errorf("invalid missing path in snapshot: %s", path)
			}
			missing[path] = true
		}
		for _, path := range record.Directories {
			if err := validPath(path); err != nil {
				return "", nil, err
			}
			allowed := false
			for _, p := range paths {
				if contains(p, path) && !missing[p] {
					allowed = true
				}
			}
			if !allowed {
				return "", nil, fmt.Errorf("unregistered snapshot directory: %s", path)
			}
		}
		base := filepath.Join(r.snapshot(app), "home")
		for _, path := range paths {
			src := filepath.Join(base, path)
			if err := noLinkedParents(r.Repository, src, false); err != nil {
				return "", nil, err
			}
			if present, err := exists(src); err != nil {
				return "", nil, err
			} else if present {
				if missing[path] {
					return "", nil, fmt.Errorf("snapshot marks existing path missing: %s", path)
				}
				if err := copyTree(src, filepath.Join(tmp, path), src, filepath.Join(tmp, path), 0); err != nil {
					return "", nil, err
				}
			} else if !missing[path] {
				isDirectory := false
				for _, p := range record.Directories {
					if p == path {
						isDirectory = true
					}
				}
				if !isDirectory {
					return "", nil, fmt.Errorf("incomplete snapshot; source missing without deletion record: %s", path)
				}
			}
		}
		for _, path := range record.Directories {
			if err := noLinkedParents(tmp, filepath.Join(tmp, path), true); err != nil {
				return "", nil, err
			}
			if err := os.MkdirAll(filepath.Join(tmp, path), 0700); err != nil {
				return "", nil, err
			}
		}
	} else {
		for _, path := range sortedKeys(r.Files) {
			managed := false
			for _, root := range paths {
				if contains(root, path) {
					managed = true
					break
				}
			}
			if !managed {
				continue
			}
			src := r.Files[path]
			if err := noLinkedParents(r.Repository, src, false); err != nil {
				return "", nil, err
			}
			if info, err := os.Lstat(src); err != nil {
				return "", nil, err
			} else if info.Mode()&os.ModeSymlink != 0 {
				resolved, err := filepath.EvalSymlinks(src)
				if err != nil {
					return "", nil, err
				}
				if !contains(filepath.Join(r.Repository, "dotfiles/config"), resolved) {
					return "", nil, fmt.Errorf("layered source link escapes checkout configuration: %s", src)
				}
				src = resolved
			}
			// Relative aliases in layered sources refer to siblings in that layer.
			root := src
			for range strings.Split(path, "/") {
				root = filepath.Dir(root)
			}
			if err := copyTree(src, filepath.Join(tmp, path), root, tmp, 0); err != nil {
				return "", nil, err
			}
		}
	}
	ok = true
	return tmp, paths, nil
}
