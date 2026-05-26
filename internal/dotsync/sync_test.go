package dotsync

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/osmargm1202/nixos/internal/dotconfig"
	"github.com/osmargm1202/nixos/internal/dotmanifest"
)

func TestRunReplacesDestinationSymlinkWhenSourceIsManagedFile(t *testing.T) {
	rt := testRuntime(t)
	managedFile := filepath.Join(rt.SourceShared, ".config", "app", "config.json")
	writeFile(t, managedFile, "repo")
	dstLink := filepath.Join(rt.Destination, ".config", "app", "config.json")
	if err := os.MkdirAll(filepath.Dir(dstLink), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink("/nix/store/generated", dstLink); err != nil {
		t.Fatal(err)
	}

	actions, err := Run(rt, Options{})
	if err != nil {
		t.Fatal(err)
	}

	assertHasAction(t, actions, "M", dstLink)
	if info, err := os.Lstat(dstLink); err != nil {
		t.Fatal(err)
	} else if info.Mode()&os.ModeSymlink != 0 {
		t.Fatal("managed file should replace destination symlink")
	}
}

func TestRunCopiesManagedSourceSymlinksEvenWhenDestinationSymlinksAreLocalOnly(t *testing.T) {
	rt := testRuntime(t)
	srcLink := filepath.Join(rt.SourceShared, ".config", "app", "managed-link")
	if err := os.MkdirAll(filepath.Dir(srcLink), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink("managed-target", srcLink); err != nil {
		t.Fatal(err)
	}

	actions, err := Run(rt, Options{})
	if err != nil {
		t.Fatal(err)
	}

	dstLink := filepath.Join(rt.Destination, ".config", "app", "managed-link")
	assertHasAction(t, actions, "A", dstLink)
	target, err := os.Readlink(dstLink)
	if err != nil {
		t.Fatalf("managed source symlink should be copied: %v", err)
	}
	if target != "managed-target" {
		t.Fatalf("symlink target = %q, want managed-target", target)
	}
}

func TestRunPreservesConfiguredLocalOnlyTypesAndPatterns(t *testing.T) {
	rt := testRuntime(t)
	writeFile(t, filepath.Join(rt.SourceShared, ".config", "app", "config.json"), "repo")
	writeFile(t, filepath.Join(rt.Destination, ".config", "app", "config.json"), "home")
	writeFile(t, filepath.Join(rt.Destination, ".config", "app", ".gitignore"), "generated")
	writeFile(t, filepath.Join(rt.Destination, ".config", "app", ".git", "config"), "git")
	linkPath := filepath.Join(rt.Destination, ".config", "app", "system-link")
	if err := os.Symlink("/nix/store/icon", linkPath); err != nil {
		t.Fatal(err)
	}

	actions, err := Run(rt, Options{})
	if err != nil {
		t.Fatal(err)
	}

	assertHasAction(t, actions, "M", filepath.Join(rt.Destination, ".config", "app", "config.json"))
	assertNoAction(t, actions, filepath.Join(rt.Destination, ".config", "app", ".gitignore"))
	assertNoAction(t, actions, filepath.Join(rt.Destination, ".config", "app", ".git", "config"))
	assertNoAction(t, actions, linkPath)
	if _, err := os.Lstat(filepath.Join(rt.Destination, ".config", "app", ".gitignore")); err != nil {
		t.Fatalf(".gitignore should be preserved: %v", err)
	}
	if _, err := os.Lstat(linkPath); err != nil {
		t.Fatalf("symlink should be preserved: %v", err)
	}
}

func testRuntime(t *testing.T) dotconfig.Runtime {
	t.Helper()
	root := t.TempDir()
	repo := filepath.Join(root, "repo")
	home := filepath.Join(root, "home")
	shared := filepath.Join(repo, "config", "shared")
	state := filepath.Join(root, "state")
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
		StateDir:     state,
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

func assertHasAction(t *testing.T, actions []Action, code, path string) {
	t.Helper()
	for _, action := range actions {
		if action.Code == code && action.Path == path {
			return
		}
	}
	t.Fatalf("missing %s action for %s in %#v", code, path, actions)
}

func assertNoAction(t *testing.T, actions []Action, path string) {
	t.Helper()
	for _, action := range actions {
		if action.Path == path {
			t.Fatalf("unexpected action for %s: %#v", path, action)
		}
	}
}
