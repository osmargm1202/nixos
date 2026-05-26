package dotconfig

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestLoadUsesRelativeOrgmDotConfigFromCurrentDirectory(t *testing.T) {
	tmp := t.TempDir()
	home := filepath.Join(tmp, "home")
	repo := filepath.Join(tmp, "repo")
	configDir := filepath.Join(repo, "config")
	if err := os.MkdirAll(configDir, 0o755); err != nil {
		t.Fatal(err)
	}
	writeFixtureConfig(t, filepath.Join(configDir, "dotfiles.json"), repo)

	oldwd, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = os.Chdir(oldwd) }()
	if err := os.Chdir(repo); err != nil {
		t.Fatal(err)
	}

	t.Setenv("HOME", home)
	t.Setenv("ORGM_DOT_CONFIG", "config/dotfiles.json")

	runtime, err := Load("")
	if err != nil {
		t.Fatal(err)
	}
	if runtime.ConfigPath != filepath.Clean("config/dotfiles.json") {
		t.Fatalf("config path should remain cwd-relative, got %q", runtime.ConfigPath)
	}
	if runtime.Repo != repo {
		t.Fatalf("repo mismatch: %q", runtime.Repo)
	}
}

func TestLoadUsesOrgmDotConfigAndExpandsPaths(t *testing.T) {
	tmp := t.TempDir()
	home := filepath.Join(tmp, "home")
	repo := filepath.Join(tmp, "repo")
	if err := os.MkdirAll(filepath.Join(repo, "config"), 0o755); err != nil {
		t.Fatal(err)
	}
	configPath := filepath.Join(repo, "config", "dotfiles.json")
	writeFixtureConfig(t, configPath, repo)

	t.Setenv("HOME", home)
	t.Setenv("ORGM_DOT_CONFIG", configPath)

	runtime, err := Load("")
	if err != nil {
		t.Fatal(err)
	}
	if runtime.Repo != repo {
		t.Fatalf("repo mismatch: %q", runtime.Repo)
	}
	if runtime.Destination != home {
		t.Fatalf("destination mismatch: %q", runtime.Destination)
	}
	if runtime.SourceShared != filepath.Join(repo, "config", "shared") {
		t.Fatalf("shared source mismatch: %q", runtime.SourceShared)
	}
	if runtime.StateDir != filepath.Join(home, ".local", "state", "orgm-dot") {
		t.Fatalf("state dir mismatch: %q", runtime.StateDir)
	}
}

func TestStatusLinesIncludeOrgmDotFieldsAndCounts(t *testing.T) {
	tmp := t.TempDir()
	home := filepath.Join(tmp, "home")
	repo := filepath.Join(tmp, "repo")
	if err := os.MkdirAll(filepath.Join(repo, "config"), 0o755); err != nil {
		t.Fatal(err)
	}
	configPath := filepath.Join(repo, "config", "dotfiles.json")
	writeFixtureConfig(t, configPath, repo)

	t.Setenv("HOME", home)
	runtime, err := Load(configPath)
	if err != nil {
		t.Fatal(err)
	}
	lines := strings.Join(runtime.StatusLines("lenovo"), "\n")
	for _, want := range []string{
		"repo:        " + repo,
		"config:      " + configPath,
		"destination: " + home,
		"shared src:  " + filepath.Join(repo, "config", "shared"),
		"host src:    " + filepath.Join(repo, "config", "hosts", "lenovo"),
		"head:        ",
		"state dir:   " + filepath.Join(home, ".local", "state", "orgm-dot"),
		"host:        lenovo",
		"managed shared: 2",
		"managed host:   1",
	} {
		if !strings.Contains(lines, want) {
			t.Fatalf("status missing %q in:\n%s", want, lines)
		}
	}
}

func TestLoadUsesDotfilesRepoForDefaultConfig(t *testing.T) {
	tmp := t.TempDir()
	home := filepath.Join(tmp, "home")
	repo := filepath.Join(tmp, "repo")
	if err := os.MkdirAll(filepath.Join(repo, "config"), 0o755); err != nil {
		t.Fatal(err)
	}
	writeFixtureConfig(t, filepath.Join(repo, "config", "dotfiles.json"), repo)

	t.Setenv("HOME", home)
	t.Setenv("DOTFILES_REPO", repo)
	t.Setenv("ORGM_DOT_CONFIG", "")

	runtime, err := Load("")
	if err != nil {
		t.Fatal(err)
	}
	wantConfig := filepath.Join(repo, "config", "dotfiles.json")
	if runtime.ConfigPath != wantConfig {
		t.Fatalf("config path mismatch: got %q want %q", runtime.ConfigPath, wantConfig)
	}
	if runtime.Repo != repo {
		t.Fatalf("repo mismatch: %q", runtime.Repo)
	}
}

func TestLoadMissingConfig(t *testing.T) {
	_, err := Load(filepath.Join(t.TempDir(), "missing.json"))
	if err == nil {
		t.Fatal("expected missing config error")
	}
}

func writeFixtureConfig(t *testing.T, path, repo string) {
	t.Helper()
	content := `{
  "settings": {
    "repo": ` + quote(repo) + `,
    "destination": "~",
    "source_shared": "config/shared",
    "source_hosts": "config/hosts",
    "state_dir": "~/.local/state/orgm-dot",
    "poll_seconds": 7
  },
  "shared": { "paths": [".config/fish", ".tmux.conf"] },
  "hosts": { "lenovo": { "paths": [".config/fish/age-host.fish"] } },
  "local_only": { "paths": [".config/fish/fish_variables"] },
  "diff": { "scan_roots": [] }
}
`
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
}

func quote(s string) string {
	return `"` + strings.ReplaceAll(s, `\`, `\\`) + `"`
}
