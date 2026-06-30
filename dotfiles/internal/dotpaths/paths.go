package dotpaths

import (
	"os"
	"path/filepath"
	"strings"
)

// Expand resolves orgm-dot config paths. Relative paths are anchored at repo.
func Expand(pathValue, repo, home string) string {
	if pathValue == "" {
		return ""
	}
	if pathValue == "~" {
		return home
	}
	if strings.HasPrefix(pathValue, "~/") {
		return filepath.Join(home, strings.TrimPrefix(pathValue, "~/"))
	}
	if filepath.IsAbs(pathValue) {
		return filepath.Clean(pathValue)
	}
	return filepath.Join(repo, pathValue)
}

// StripSlashes normalizes manifest paths.
func StripSlashes(pathValue string) string {
	pathValue = strings.TrimPrefix(pathValue, "./")
	pathValue = strings.TrimPrefix(pathValue, "/")
	pathValue = strings.TrimSuffix(pathValue, "/")
	return pathValue
}

func HomeDir() string {
	if home := os.Getenv("HOME"); home != "" {
		return home
	}
	home, _ := os.UserHomeDir()
	return home
}
