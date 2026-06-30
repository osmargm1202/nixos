package wallpaper

import (
	"os"
	"path/filepath"
)

// CleanStaleThumbnails removes folder-local thumbnail cache entries whose
// source wallpaper no longer exists under wallpaperRoot.
func CleanStaleThumbnails(wallpaperRoot string) error {
	info, err := os.Stat(wallpaperRoot)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return err
	}
	if !info.IsDir() {
		return nil
	}

	return filepath.WalkDir(wallpaperRoot, func(path string, entry os.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if entry.IsDir() {
			return nil
		}
		if filepath.Ext(path) != ".jpg" {
			return nil
		}

		thumbDir := filepath.Dir(path)
		if filepath.Base(thumbDir) != ".thumb" {
			return nil
		}

		wallpaperDir := filepath.Dir(thumbDir)
		wallpaperBase := filepath.Base(path[:len(path)-len(".jpg")])
		wallpaperPath := filepath.Join(wallpaperDir, wallpaperBase)
		if _, err := os.Stat(wallpaperPath); err == nil {
			return nil
		} else if !os.IsNotExist(err) {
			return err
		}
		return os.Remove(path)
	})
}
