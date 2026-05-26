package dotmanifest

import (
	"sort"
	"strings"
)

// Normalize trims leading ./, leading /, and trailing / from manifest paths.
func Normalize(pathValue string) string {
	pathValue = strings.TrimPrefix(pathValue, "./")
	pathValue = strings.TrimPrefix(pathValue, "/")
	pathValue = strings.TrimSuffix(pathValue, "/")
	return pathValue
}

// ContainsNested reports whether rel is exactly managed or nested under a managed path.
func ContainsNested(paths []string, rel string) bool {
	rel = Normalize(rel)
	for _, managed := range paths {
		managed = Normalize(managed)
		if rel == managed || strings.HasPrefix(rel, managed+"/") {
			return true
		}
	}
	return false
}

func AddUnique(paths []string, rel string) []string {
	rel = Normalize(rel)
	seen := map[string]bool{rel: true}
	out := []string{rel}
	for _, path := range paths {
		path = Normalize(path)
		if path == "" || seen[path] {
			continue
		}
		seen[path] = true
		out = append(out, path)
	}
	sort.Strings(out)
	return out
}

func Remove(paths []string, rel string) []string {
	rel = Normalize(rel)
	out := make([]string, 0, len(paths))
	for _, path := range paths {
		path = Normalize(path)
		if path == "" || path == rel {
			continue
		}
		out = append(out, path)
	}
	sort.Strings(out)
	return out
}

func Count(paths []string) int {
	return len(paths)
}
