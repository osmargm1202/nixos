package dotmanifest

import (
	"path"
	"regexp"
	"strings"
)

type LocalOnlyRules struct {
	Paths    []string `json:"paths"`
	Patterns []string `json:"patterns"`
	Types    []string `json:"types"`
}

func (r LocalOnlyRules) Matches(rel string, isSymlink bool) bool {
	rel = Normalize(rel)
	if ContainsNested(r.Paths, rel) {
		return true
	}
	if isSymlink && containsType(r.Types, "symlink") {
		return true
	}
	for _, pattern := range r.Patterns {
		if matchGlob(pattern, rel) {
			return true
		}
	}
	return false
}

func containsType(types []string, want string) bool {
	for _, typ := range types {
		if strings.EqualFold(strings.TrimSpace(typ), want) {
			return true
		}
	}
	return false
}

func matchGlob(pattern, rel string) bool {
	pattern = Normalize(pattern)
	if pattern == "" {
		return false
	}
	if ok, _ := path.Match(pattern, rel); ok {
		return true
	}
	re, err := regexp.Compile("^" + globToRegex(pattern) + "$")
	if err != nil {
		return false
	}
	return re.MatchString(rel)
}

func globToRegex(pattern string) string {
	var b strings.Builder
	for i := 0; i < len(pattern); i++ {
		switch pattern[i] {
		case '*':
			if i+1 < len(pattern) && pattern[i+1] == '*' {
				b.WriteString(".*")
				i++
			} else {
				b.WriteString("[^/]*")
			}
		case '?':
			b.WriteString("[^/]")
		default:
			b.WriteString(regexp.QuoteMeta(string(pattern[i])))
		}
	}
	return b.String()
}
