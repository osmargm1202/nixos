package dotsync

import (
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"syscall"

	"github.com/osmargm1202/nixos/internal/dotconfig"
	"github.com/osmargm1202/nixos/internal/dotmanifest"
)

type Options struct {
	Host   string
	DryRun bool
	Target string
}

type Action struct {
	Code string
	Path string
}

type DesktopProfile string

const (
	DesktopAll      DesktopProfile = "all"
	DesktopHyprland DesktopProfile = "hyprland"
	DesktopGNOME    DesktopProfile = "gnome"
	DesktopLabwc    DesktopProfile = "labwc"
	DesktopSway     DesktopProfile = "sway"
)

type envLookup func(string) string

func desktopProfileFromEnv(lookup envLookup) (DesktopProfile, error) {
	if override := strings.TrimSpace(strings.ToLower(lookup("ORGM_DOT_DESKTOP"))); override != "" {
		switch override {
		case string(DesktopAll):
			return DesktopAll, nil
		case string(DesktopHyprland):
			return DesktopHyprland, nil
		case string(DesktopGNOME):
			return DesktopGNOME, nil
		case string(DesktopLabwc):
			return DesktopLabwc, nil
		case string(DesktopSway):
			return DesktopSway, nil
		default:
			return "", fmt.Errorf("invalid ORGM_DOT_DESKTOP %q: expected hyprland, gnome, labwc, sway, or all", override)
		}
	}

	if strings.TrimSpace(lookup("HYPRLAND_INSTANCE_SIGNATURE")) != "" {
		return DesktopHyprland, nil
	}

	joined := strings.ToLower(strings.Join([]string{
		lookup("XDG_CURRENT_DESKTOP"),
		lookup("DESKTOP_SESSION"),
		lookup("XDG_SESSION_DESKTOP"),
	}, ":"))

	switch {
	case strings.Contains(joined, "hyprland"):
		return DesktopHyprland, nil
	case strings.Contains(joined, "gnome"):
		return DesktopGNOME, nil
	case strings.Contains(joined, "labwc"):
		return DesktopLabwc, nil
	case strings.Contains(joined, "sway"):
		return DesktopSway, nil
	default:
		return DesktopAll, nil
	}
}

func currentDesktopProfile() (DesktopProfile, error) {
	return desktopProfileFromEnv(os.Getenv)
}

func CurrentDesktopProfile() (DesktopProfile, error) {
	return currentDesktopProfile()
}

func ShouldSyncPath(profile DesktopProfile, rel string) bool {
	return shouldSyncPath(profile, rel)
}

func shouldSyncPath(profile DesktopProfile, rel string) bool {
	rel = dotmanifest.Normalize(rel)
	switch profile {
	case DesktopGNOME:
		return !isAnyDesktopSpecificPath(rel)
	case DesktopLabwc:
		return !isHyprlandPath(rel) && !isSwayPath(rel)
	case DesktopSway:
		return !isHyprlandPath(rel)
	case DesktopHyprland:
		return !isLabwcPath(rel) && !isSwayOnlyPath(rel)
	case DesktopAll, "":
		return true
	default:
		return true
	}
}

func isAnyDesktopSpecificPath(rel string) bool {
	return isHyprlandPath(rel) || isLabwcPath(rel) || isSwayPath(rel) || hasPathPrefix(rel, ".config/waybar") || isDesktopHelper(rel)
}

func isHyprlandPath(rel string) bool {
	return hasPathPrefix(rel, ".config/hypr") ||
		hasPathPrefix(rel, ".config/orgm-hypr") ||
		hasPathPrefix(rel, ".config/waybar-hypr") ||
		hasPathPrefix(rel, ".config/nwg-dock-hyprland") ||
		hasBasePrefix(rel, "hypr-") ||
		rel == ".local/bin/fuzzel-hypr-window" ||
		rel == ".local/bin/brightness-osd" ||
		rel == ".local/bin/mic-volume-osd" ||
		rel == ".local/bin/volume-osd" ||
		rel == ".local/bin/waybar-date-es" ||
		rel == ".local/bin/waybar-day-month-es" ||
		rel == ".local/bin/waybar-swap-usage" ||
		rel == ".local/bin/waybar-time-ampm" ||
		rel == ".local/bin/waybar-watch"
}

func isLabwcPath(rel string) bool {
	return hasPathPrefix(rel, ".config/labwc") || hasBasePrefix(rel, "labwc-")
}

func isSwayPath(rel string) bool {
	return isSwayOnlyPath(rel) || hasPathPrefix(rel, ".config/swaync")
}

func isSwayOnlyPath(rel string) bool {
	return hasPathPrefix(rel, ".config/sway") ||
		hasPathPrefix(rel, ".config/swaylock") ||
		hasBasePrefix(rel, "sway-")
}

func isDesktopHelper(rel string) bool {
	return hasBasePrefix(rel, "hypr-") || hasBasePrefix(rel, "labwc-") || hasBasePrefix(rel, "sway-") ||
		rel == ".local/bin/fuzzel-hypr-window" ||
		strings.HasPrefix(filepath.Base(rel), "waybar-") ||
		strings.HasSuffix(filepath.Base(rel), "-osd")
}

func hasPathPrefix(rel, prefix string) bool {
	return rel == prefix || strings.HasPrefix(rel, prefix+"/")
}

func hasBasePrefix(rel, prefix string) bool {
	return strings.HasPrefix(filepath.Base(rel), prefix)
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

	profile, err := currentDesktopProfile()
	if err != nil {
		return nil, err
	}

	if opts.Target != "" {
		return syncTarget(rt, profile, opts)
	}

	var actions []Action
	for _, rel := range rt.Config.Shared.Paths {
		if !shouldSyncPath(profile, rel) {
			continue
		}
		as, err := syncOne(rt, rt.SourceShared, rel, profile, opts)
		if err != nil {
			return nil, err
		}
		actions = append(actions, as...)
	}
	for _, rel := range rt.HostPaths(opts.Host) {
		if !shouldSyncPath(profile, rel) {
			continue
		}
		as, err := syncOne(rt, rt.HostSource(opts.Host), rel, profile, opts)
		if err != nil {
			return nil, err
		}
		actions = append(actions, as...)
	}
	for _, rel := range rt.Config.LocalDefaults.Paths {
		as, err := syncLocalDefault(rt, rel, profile, opts)
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

func syncTarget(rt dotconfig.Runtime, profile DesktopProfile, opts Options) ([]Action, error) {
	target := dotmanifest.Normalize(opts.Target)
	if target == "" {
		return nil, fmt.Errorf("sync target path is empty")
	}

	var actions []Action
	matched := false
	for _, managed := range rt.Config.Shared.Paths {
		if !targetWithinManaged(target, managed) {
			continue
		}
		matched = true
		if !shouldSyncPath(profile, target) {
			continue
		}
		as, err := syncOne(rt, rt.SourceShared, target, profile, opts)
		if err != nil {
			return nil, err
		}
		actions = append(actions, as...)
	}
	for _, managed := range rt.HostPaths(opts.Host) {
		if !targetWithinManaged(target, managed) {
			continue
		}
		matched = true
		if !shouldSyncPath(profile, target) {
			continue
		}
		as, err := syncOne(rt, rt.HostSource(opts.Host), target, profile, opts)
		if err != nil {
			return nil, err
		}
		actions = append(actions, as...)
	}
	for _, managed := range rt.Config.LocalDefaults.Paths {
		if !targetSelectsLocalDefault(target, managed) {
			continue
		}
		matched = true
		as, err := syncLocalDefault(rt, managed, profile, opts)
		if err != nil {
			return nil, err
		}
		actions = append(actions, as...)
	}
	if !matched {
		return nil, fmt.Errorf("sync target %q is not managed", target)
	}
	sort.SliceStable(actions, func(i, j int) bool { return actions[i].Path < actions[j].Path })
	return actions, nil
}

func targetWithinManaged(target, managed string) bool {
	managed = dotmanifest.Normalize(managed)
	return target == managed || strings.HasPrefix(target, managed+"/")
}

func targetSelectsLocalDefault(target, managed string) bool {
	managed = dotmanifest.Normalize(managed)
	return target == managed || strings.HasPrefix(managed, target+"/")
}

func syncOne(rt dotconfig.Runtime, base, rel string, profile DesktopProfile, opts Options) ([]Action, error) {
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
	if rt.Config.LocalOnly.Matches(rel, false) || !shouldSyncPath(profile, rel) {
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
		if rt.Config.LocalOnly.Matches(itemRel, false) || !shouldSyncPath(profile, itemRel) {
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
			if isLocalOnly(rt, itemRel, path) || !shouldSyncPath(profile, itemRel) {
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

func syncLocalDefault(rt dotconfig.Runtime, rel string, profile DesktopProfile, opts Options) ([]Action, error) {
	rel = dotmanifest.Normalize(rel)
	if !shouldSyncPath(profile, rel) {
		return nil, nil
	}
	src := filepath.Join(rt.SourceShared, rel)
	if _, err := os.Lstat(src); os.IsNotExist(err) {
		return nil, nil
	} else if err != nil {
		return nil, err
	}
	dst := filepath.Join(rt.Destination, rel)
	if _, err := os.Lstat(dst); err == nil {
		return nil, nil
	} else if !os.IsNotExist(err) {
		return nil, err
	}
	action := Action{Code: "A", Path: dst}
	if opts.DryRun {
		return []Action{action}, nil
	}
	if err := copyFileOrSymlink(src, dst); err != nil {
		return nil, err
	}
	return []Action{action}, nil
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
