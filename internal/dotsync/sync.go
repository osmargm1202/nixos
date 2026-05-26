package dotsync

import (
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"syscall"

	"github.com/osmargm1202/nixos/internal/dotconfig"
	"github.com/osmargm1202/nixos/internal/dotmanifest"
)

type Options struct {
	Host   string
	DryRun bool
}

type Action struct {
	Code string
	Path string
}

func Run(rt dotconfig.Runtime, opts Options) ([]Action, error) {
	if err := os.MkdirAll(rt.StateDir, 0o755); err != nil {
		return nil, err
	}
	lock := filepath.Join(rt.StateDir, "sync.lock")
	lockFile, err := os.OpenFile(lock, os.O_CREATE|os.O_RDWR, 0o644)
	if err != nil {
		return nil, err
	}
	defer lockFile.Close()
	if err := syscall.Flock(int(lockFile.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		return nil, fmt.Errorf("sync already running")
	}
	defer syscall.Flock(int(lockFile.Fd()), syscall.LOCK_UN)

	var actions []Action
	for _, rel := range rt.Config.Shared.Paths {
		as, err := syncOne(rt, rt.SourceShared, rel, opts)
		if err != nil {
			return nil, err
		}
		actions = append(actions, as...)
	}
	for _, rel := range rt.HostPaths(opts.Host) {
		as, err := syncOne(rt, rt.HostSource(opts.Host), rel, opts)
		if err != nil {
			return nil, err
		}
		actions = append(actions, as...)
	}
	return actions, nil
}

func Format(actions []Action) []string {
	lines := make([]string, 0, len(actions))
	for _, action := range actions {
		lines = append(lines, fmt.Sprintf("%s  %s", action.Code, action.Path))
	}
	return lines
}

func syncOne(rt dotconfig.Runtime, base, rel string, opts Options) ([]Action, error) {
	rel = dotmanifest.Normalize(rel)
	src := filepath.Join(base, rel)
	dst := filepath.Join(rt.Destination, rel)
	info, err := os.Lstat(src)
	if os.IsNotExist(err) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	if rt.Config.LocalOnly.Matches(rel, false) {
		return nil, nil
	}
	if !info.IsDir() {
		return copyPath(rt, src, dst, rel, opts)
	}
	var actions []Action
	if err := filepath.WalkDir(src, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		relPart, err := filepath.Rel(src, path)
		if err != nil {
			return err
		}
		if relPart == "." {
			if !opts.DryRun {
				return os.MkdirAll(dst, info.Mode().Perm())
			}
			return nil
		}
		itemRel := filepath.ToSlash(filepath.Join(rel, relPart))
		itemDst := filepath.Join(rt.Destination, itemRel)
		if rt.Config.LocalOnly.Matches(itemRel, false) {
			if d.IsDir() {
				return filepath.SkipDir
			}
			return nil
		}
		if d.IsDir() {
			if opts.DryRun {
				return nil
			}
			entryInfo, err := d.Info()
			if err != nil {
				return err
			}
			return os.MkdirAll(itemDst, entryInfo.Mode().Perm())
		}
		as, err := copyPath(rt, path, itemDst, itemRel, opts)
		if err != nil {
			return err
		}
		actions = append(actions, as...)
		return nil
	}); err != nil {
		return nil, err
	}
	if dstInfo, err := os.Stat(dst); err == nil && dstInfo.IsDir() {
		if err := filepath.WalkDir(dst, func(path string, d fs.DirEntry, err error) error {
			if err != nil {
				return err
			}
			if d.IsDir() {
				return nil
			}
			relPart, err := filepath.Rel(dst, path)
			if err != nil {
				return err
			}
			itemRel := filepath.ToSlash(filepath.Join(rel, relPart))
			if isLocalOnly(rt, itemRel, path) {
				return nil
			}
			if _, err := os.Lstat(filepath.Join(src, relPart)); err == nil {
				return nil
			}
			actions = append(actions, Action{Code: "D", Path: filepath.Join(rt.Destination, itemRel)})
			if !opts.DryRun {
				return os.Remove(path)
			}
			return nil
		}); err != nil {
			return nil, err
		}
	}
	sort.SliceStable(actions, func(i, j int) bool { return actions[i].Path < actions[j].Path })
	return actions, nil
}

func isLocalOnly(rt dotconfig.Runtime, rel, fullPath string) bool {
	isSymlink := false
	if info, err := os.Lstat(fullPath); err == nil {
		isSymlink = info.Mode()&os.ModeSymlink != 0
	}
	return rt.Config.LocalOnly.Matches(rel, isSymlink)
}

func copyPath(rt dotconfig.Runtime, src, dst, rel string, opts Options) ([]Action, error) {
	same, err := sameContent(src, dst)
	if err == nil && same {
		return nil, nil
	}
	code := "A"
	if err == nil {
		code = "M"
	}
	action := Action{Code: code, Path: filepath.Join(rt.Destination, rel)}
	if opts.DryRun {
		return []Action{action}, nil
	}
	if err := copyFileOrSymlink(src, dst); err != nil {
		return nil, err
	}
	return []Action{action}, nil
}

func sameContent(src, dst string) (bool, error) {
	srcInfo, err := os.Lstat(src)
	if err != nil {
		return false, err
	}
	dstInfo, err := os.Lstat(dst)
	if err != nil {
		return false, err
	}
	if srcInfo.Mode()&os.ModeSymlink != 0 || dstInfo.Mode()&os.ModeSymlink != 0 {
		if srcInfo.Mode()&os.ModeSymlink == 0 || dstInfo.Mode()&os.ModeSymlink == 0 {
			return false, nil
		}
		s, err := os.Readlink(src)
		if err != nil {
			return false, err
		}
		d, err := os.Readlink(dst)
		if err != nil {
			return false, err
		}
		return s == d, nil
	}
	if !srcInfo.Mode().IsRegular() || !dstInfo.Mode().IsRegular() {
		return true, nil
	}
	if srcInfo.Size() != dstInfo.Size() {
		return false, nil
	}
	s, err := os.ReadFile(src)
	if err != nil {
		return false, err
	}
	d, err := os.ReadFile(dst)
	if err != nil {
		return false, err
	}
	return string(s) == string(d), nil
}

func copyFileOrSymlink(src, dst string) error {
	info, err := os.Lstat(src)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return err
	}
	_ = os.RemoveAll(dst)
	if info.Mode()&os.ModeSymlink != 0 {
		target, err := os.Readlink(src)
		if err != nil {
			return err
		}
		return os.Symlink(target, dst)
	}
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()
	out, err := os.OpenFile(dst, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, info.Mode().Perm())
	if err != nil {
		return err
	}
	if _, err := io.Copy(out, in); err != nil {
		_ = out.Close()
		return err
	}
	return out.Close()
}
