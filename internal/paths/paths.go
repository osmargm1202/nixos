package paths

import "path/filepath"

// ThumbPath returns the folder-local thumbnail cache path used by the shell
// wallpaper manager and Quickshell picker.
func ThumbPath(wallpaperPath string) string {
	dir := filepath.Dir(wallpaperPath)
	base := filepath.Base(wallpaperPath)
	return filepath.Join(dir, ".thumb", base+".jpg")
}
