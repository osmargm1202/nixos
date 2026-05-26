package dotmanifest

import "testing"

func TestLocalOnlyRulesMatchNestedPathsPatternsAndSymlinks(t *testing.T) {
	rules := LocalOnlyRules{
		Paths:    []string{".config/fish/fish_variables"},
		Patterns: []string{"**/.git", "**/.git/**", "**/.gitignore", "**/icon-theme.cache"},
		Types:    []string{"symlink"},
	}

	cases := []struct {
		name      string
		rel       string
		isSymlink bool
		want      bool
	}{
		{"exact path", ".config/fish/fish_variables", false, true},
		{"nested path", ".config/fish/fish_variables/generated", false, true},
		{"git dir", ".config/app/.git", false, true},
		{"git contents", ".config/app/.git/config", false, true},
		{"gitignore", ".config/app/.gitignore", false, true},
		{"icon cache", ".local/share/icons/theme/icon-theme.cache", false, true},
		{"symlink", ".local/share/icons/default/index.theme", true, true},
		{"regular managed file", ".config/app/config.json", false, false},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got := rules.Matches(tc.rel, tc.isSymlink)
			if got != tc.want {
				t.Fatalf("Matches(%q, %v) = %v, want %v", tc.rel, tc.isSymlink, got, tc.want)
			}
		})
	}
}
