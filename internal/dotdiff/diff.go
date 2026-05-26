package dotdiff

import (
	"bytes"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"sort"

	"github.com/osmargm1202/nixos/internal/dotconfig"
	"github.com/osmargm1202/nixos/internal/dotmanifest"
)

type Change struct {
	Code string
	Path string
}

type Options struct {
	Host      string
	Porcelain bool
	Verbose   bool
}

func Changes(rt dotconfig.Runtime, opts Options) ([]Change, error) {
	var changes []Change
	for _, rel := range rt.Config.Shared.Paths {
		cs, err := diffSourcePath(rt, rt.SourceShared, rel, opts)
		if err != nil {
			return nil, err
		}
		changes = append(changes, cs...)
	}
	for _, rel := range rt.HostPaths(opts.Host) {
		cs, err := diffSourcePath(rt, rt.HostSource(opts.Host), rel, opts)
		if err != nil {
			return nil, err
		}
		changes = append(changes, cs...)
	}
	return changes, nil
}

func Format(changes []Change, host string, porcelain bool) []string {
	lines := make([]string, 0, len(changes)+1)
	if !porcelain {
		lines = append(lines, fmt.Sprintf("orgm-dot diff --host %s", host))
	}
	for _, change := range changes {
		if porcelain {
			lines = append(lines, fmt.Sprintf("%s\t%s", change.Code, change.Path))
		} else {
			lines = append(lines, fmt.Sprintf("%s  %s", change.Code, change.Path))
		}
	}
	return lines
}

func diffSourcePath(rt dotconfig.Runtime, base, rel string, opts Options) ([]Change, error) {
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
	if !info.IsDir() {
		return comparePath(rt, src, dst, rel, opts)
	}

	var changes []Change
	if err := filepath.WalkDir(src, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			return nil
		}
		relPart, err := filepath.Rel(src, path)
		if err != nil {
			return err
		}
		itemRel := filepath.ToSlash(filepath.Join(rel, relPart))
		cs, err := comparePath(rt, path, filepath.Join(rt.Destination, itemRel), itemRel, opts)
		if err != nil {
			return err
		}
		changes = append(changes, cs...)
		return nil
	}); err != nil {
		return nil, err
	}

	if dstInfo, err := os.Stat(dst); err != nil || !dstInfo.IsDir() {
		return changes, nil
	}
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
			if opts.Verbose {
				changes = append(changes, Change{Code: "L", Path: filepath.Join(rt.Destination, itemRel)})
			}
			return nil
		}
		if _, err := os.Lstat(filepath.Join(src, relPart)); err == nil {
			return nil
		}
		if sourceExistsForManagedPath(rt, opts.Host, itemRel) {
			return nil
		}
		changes = append(changes, Change{Code: "R", Path: filepath.Join(rt.Destination, itemRel)})
		return nil
	}); err != nil {
		return nil, err
	}

	sort.SliceStable(changes, func(i, j int) bool { return changes[i].Path < changes[j].Path })
	return changes, nil
}

func comparePath(rt dotconfig.Runtime, src, dst, rel string, opts Options) ([]Change, error) {
	if rt.Config.LocalOnly.Matches(rel, false) {
		if opts.Verbose {
			return []Change{{Code: "L", Path: filepath.Join(rt.Destination, rel)}}, nil
		}
		return nil, nil
	}
	if _, err := os.Lstat(dst); os.IsNotExist(err) {
		return []Change{{Code: "A", Path: filepath.Join(rt.Destination, rel)}}, nil
	} else if err != nil {
		return nil, err
	}
	equal, err := sameFileContent(src, dst)
	if err != nil {
		return nil, err
	}
	if !equal {
		return []Change{{Code: "M", Path: filepath.Join(rt.Destination, rel)}}, nil
	}
	return nil, nil
}

func isLocalOnly(rt dotconfig.Runtime, rel, fullPath string) bool {
	isSymlink := false
	if info, err := os.Lstat(fullPath); err == nil {
		isSymlink = info.Mode()&os.ModeSymlink != 0
	}
	return rt.Config.LocalOnly.Matches(rel, isSymlink)
}

func sourceExistsForManagedPath(rt dotconfig.Runtime, host, rel string) bool {
	if _, err := os.Lstat(filepath.Join(rt.SourceShared, rel)); err == nil {
		return true
	}
	if host != "" {
		if _, err := os.Lstat(filepath.Join(rt.HostSource(host), rel)); err == nil {
			return true
		}
	}
	return false
}

func sameFileContent(src, dst string) (bool, error) {
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
		srcTarget, err := os.Readlink(src)
		if err != nil {
			return false, err
		}
		dstTarget, err := os.Readlink(dst)
		if err != nil {
			return false, err
		}
		return srcTarget == dstTarget, nil
	}
	if !srcInfo.Mode().IsRegular() || !dstInfo.Mode().IsRegular() {
		return true, nil
	}
	if srcInfo.Size() != dstInfo.Size() {
		return false, nil
	}
	srcBytes, err := os.ReadFile(src)
	if err != nil {
		return false, err
	}
	dstBytes, err := os.ReadFile(dst)
	if err != nil {
		return false, err
	}
	return bytes.Equal(srcBytes, dstBytes), nil
}
