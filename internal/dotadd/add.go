package dotadd

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/osmargm1202/nixos/internal/dotconfig"
	"github.com/osmargm1202/nixos/internal/dotmanifest"
)

type Options struct {
	Host   string
	Scope  string
	Target string
}

func Add(rt dotconfig.Runtime, opts Options) (string, error) {
	rel, err := NormalizeTarget(rt, opts.Target)
	if err != nil {
		return "", err
	}
	localPath := filepath.Join(rt.Destination, rel)
	if _, err := os.Lstat(localPath); err != nil {
		return "", fmt.Errorf("local path does not exist: %s", localPath)
	}
	targetSrc := filepath.Join(sourceBase(rt, opts), rel)
	if err := copyTree(localPath, targetSrc, rel, rt.Config.LocalOnly.Paths); err != nil {
		return "", err
	}
	cfg := rt.Config
	cfg.LocalOnly.Paths = dotmanifest.Remove(cfg.LocalOnly.Paths, rel)
	if opts.Scope == "shared" {
		cfg.Shared.Paths = dotmanifest.AddUnique(cfg.Shared.Paths, rel)
	} else {
		ensureHost(&cfg, opts.Host)
		host := cfg.Hosts[opts.Host]
		host.Paths = dotmanifest.AddUnique(host.Paths, rel)
		cfg.Hosts[opts.Host] = host
	}
	if err := writeConfig(rt.ConfigPath, cfg); err != nil {
		return "", err
	}
	return fmt.Sprintf("A  %s -> %s", rel, targetSrc), nil
}

func Remove(rt dotconfig.Runtime, opts Options) (string, error) {
	rel, err := NormalizeTarget(rt, opts.Target)
	if err != nil {
		return "", err
	}
	targetSrc := filepath.Join(sourceBase(rt, opts), rel)
	if err := os.RemoveAll(targetSrc); err != nil {
		return "", err
	}
	cfg := rt.Config
	if opts.Scope == "shared" {
		cfg.Shared.Paths = dotmanifest.Remove(cfg.Shared.Paths, rel)
	} else {
		ensureHost(&cfg, opts.Host)
		host := cfg.Hosts[opts.Host]
		host.Paths = dotmanifest.Remove(host.Paths, rel)
		cfg.Hosts[opts.Host] = host
	}
	cfg.LocalOnly.Paths = dotmanifest.AddUnique(cfg.LocalOnly.Paths, rel)
	if err := writeConfig(rt.ConfigPath, cfg); err != nil {
		return "", err
	}
	return fmt.Sprintf("R  %s removed from source; local preserved", rel), nil
}

func NormalizeTarget(rt dotconfig.Runtime, target string) (string, error) {
	if strings.HasPrefix(target, "~/") {
		target = filepath.Join(rt.Home, strings.TrimPrefix(target, "~/"))
	} else if !filepath.IsAbs(target) {
		cwd, err := os.Getwd()
		if err != nil {
			return "", fmt.Errorf("get working directory: %w", err)
		}
		target = filepath.Join(cwd, target)
	}

	cleanDest := filepath.Clean(rt.Destination)
	cleanTarget := filepath.Clean(target)
	if cleanTarget == cleanDest {
		return "", fmt.Errorf("target must be inside destination: %s", rt.Destination)
	}
	rel, err := filepath.Rel(cleanDest, cleanTarget)
	if err != nil || strings.HasPrefix(rel, "..") || filepath.IsAbs(rel) {
		return "", fmt.Errorf("target must be inside destination: %s", rt.Destination)
	}
	return filepath.ToSlash(dotmanifest.Normalize(rel)), nil
}

func sourceBase(rt dotconfig.Runtime, opts Options) string {
	if opts.Scope == "shared" {
		return rt.SourceShared
	}
	return rt.HostSource(opts.Host)
}

func ensureHost(cfg *dotconfig.Config, host string) {
	if cfg.Hosts == nil {
		cfg.Hosts = map[string]dotconfig.PathList{}
	}
	if _, ok := cfg.Hosts[host]; !ok {
		cfg.Hosts[host] = dotconfig.PathList{}
	}
}

func writeConfig(path string, cfg dotconfig.Config) error {
	data, err := json.MarshalIndent(cfg, "", "  ")
	if err != nil {
		return err
	}
	data = append(data, '\n')
	tmp := fmt.Sprintf("%s.tmp.%d", path, os.Getpid())
	if err := os.WriteFile(tmp, data, 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

func copyTree(src, dst, rel string, localOnly []string) error {
	info, err := os.Lstat(src)
	if err != nil {
		return err
	}
	if dotmanifest.ContainsNested(localOnly, rel) {
		return nil
	}
	if !info.IsDir() {
		return copyFileOrSymlink(src, dst)
	}
	if err := os.RemoveAll(dst); err != nil {
		return err
	}
	return filepath.WalkDir(src, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			return err
		}
		relPart, err := filepath.Rel(src, path)
		if err != nil {
			return err
		}
		itemRel := filepath.ToSlash(filepath.Join(rel, relPart))
		if relPart != "." && dotmanifest.ContainsNested(localOnly, itemRel) {
			if d.IsDir() {
				return filepath.SkipDir
			}
			return nil
		}
		itemDst := filepath.Join(dst, relPart)
		entryInfo, err := os.Lstat(path)
		if err != nil {
			return err
		}
		if d.IsDir() {
			return os.MkdirAll(itemDst, entryInfo.Mode().Perm())
		}
		return copyFileOrSymlink(path, itemDst)
	})
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
	data, err := os.ReadFile(src)
	if err != nil {
		return err
	}
	return os.WriteFile(dst, data, info.Mode().Perm())
}
