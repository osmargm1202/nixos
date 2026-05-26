package dotdiff

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/osmargm1202/nixos/internal/dotconfig"
	"github.com/osmargm1202/nixos/internal/dotmanifest"
)

func TestChangesReportsManagedFilesWhenDestinationIsSymlink(t *testing.T) {
	rt := testRuntime(t)
	writeFile(t, filepath.Join(rt.SourceShared, ".config", "app", "config.json"), "repo")
	dstLink := filepath.Join(rt.Destination, ".config", "app", "config.json")
	if err := os.MkdirAll(filepath.Dir(dstLink), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink("/nix/store/generated", dstLink); err != nil {
		t.Fatal(err)
	}

	changes, err := Changes(rt, Options{})
	if err != nil {
		t.Fatal(err)
	}

	assertHasChange(t, changes, "M", dstLink)
}

func TestChangesReportsManagedSourceSymlinksEvenWhenDestinationSymlinksAreLocalOnly(t *testing.T) {
	rt := testRuntime(t)
	srcLink := filepath.Join(rt.SourceShared, ".config", "app", "managed-link")
	if err := os.MkdirAll(filepath.Dir(srcLink), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink("managed-target", srcLink); err != nil {
		t.Fatal(err)
	}

	changes, err := Changes(rt, Options{})
	if err != nil {
		t.Fatal(err)
	}

	assertHasChange(t, changes, "A", filepath.Join(rt.Destination, ".config", "app", "managed-link"))
}

func TestChangesTreatsConfiguredTypesAndPatternsAsLocalOnly(t *testing.T) {
	rt := testRuntime(t)
	writeFile(t, filepath.Join(rt.SourceShared, ".config", "app", "config.json"), "repo")
	writeFile(t, filepath.Join(rt.Destination, ".config", "app", "config.json"), "home")
	writeFile(t, filepath.Join(rt.Destination, ".config", "app", ".gitignore"), "generated")
	writeFile(t, filepath.Join(rt.Destination, ".config", "app", ".git", "config"), "git")
	if err := os.Symlink("/nix/store/icon", filepath.Join(rt.Destination, ".config", "app", "system-link")); err != nil {
		t.Fatal(err)
	}

	changes, err := Changes(rt, Options{})
	if err != nil {
		t.Fatal(err)
	}

	assertHasChange(t, changes, "M", filepath.Join(rt.Destination, ".config", "app", "config.json"))
	assertNoChange(t, changes, filepath.Join(rt.Destination, ".config", "app", ".gitignore"))
	assertNoChange(t, changes, filepath.Join(rt.Destination, ".config", "app", ".git", "config"))
	assertNoChange(t, changes, filepath.Join(rt.Destination, ".config", "app", "system-link"))
}

func testRuntime(t *testing.T) dotconfig.Runtime {
	t.Helper()
	root := t.TempDir()
	repo := filepath.Join(root, "repo")
	home := filepath.Join(root, "home")
	shared := filepath.Join(repo, "config", "shared")
	if err := os.MkdirAll(shared, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(home, 0o755); err != nil {
		t.Fatal(err)
	}
	return dotconfig.Runtime{
		Repo:         repo,
		Destination:  home,
		SourceShared: shared,
		Config: dotconfig.Config{
			Shared: dotconfig.PathList{Paths: []string{".config/app"}},
			LocalOnly: dotmanifest.LocalOnlyRules{
				Patterns: []string{"**/.git", "**/.git/**", "**/.gitignore"},
				Types:    []string{"symlink"},
			},
		},
	}
}

func writeFile(t *testing.T, path, content string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
}

func assertHasChange(t *testing.T, changes []Change, code, path string) {
	t.Helper()
	for _, change := range changes {
		if change.Code == code && change.Path == path {
			return
		}
	}
	t.Fatalf("missing %s change for %s in %#v", code, path, changes)
}

func assertNoChange(t *testing.T, changes []Change, path string) {
	t.Helper()
	for _, change := range changes {
		if change.Path == path {
			t.Fatalf("unexpected change for %s: %#v", path, change)
		}
	}
}
