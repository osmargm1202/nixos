package main

import (
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"runtime"
	"strings"
	"testing"
)

func TestFailedSecondInstallRollsBackEarlierPaths(t *testing.T) {
	r := fixture(t)
	app, _ := r.app("demo")
	put(t, filepath.Join(r.Home, ".config/demo/old"), "old directory")
	put(t, filepath.Join(r.Home, ".demo-file"), "old file")
	previous := renamePath
	renamePath = func(from, to string) error {
		if filepath.Base(from) == "new" && to == filepath.Join(r.Home, ".demo-file") {
			return fmt.Errorf("injected rename failure")
		}
		return os.Rename(from, to)
	}
	defer func() { renamePath = previous }()
	if _, err := r.apply(app); err == nil {
		t.Fatal("expected commit failure")
	}
	if textAt(t, filepath.Join(r.Home, ".config/demo/old")) != "old directory" || textAt(t, filepath.Join(r.Home, ".demo-file")) != "old file" {
		t.Fatal("rollback did not restore both roots")
	}
	if present, _ := exists(filepath.Join(r.Home, ".config/demo/settings")); present {
		t.Fatal("partially applied config left behind")
	}
}

func put(t *testing.T, path, text string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(text), 0644); err != nil {
		t.Fatal(err)
	}
}
func textAt(t *testing.T, path string) string {
	t.Helper()
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	return string(data)
}
func must(t *testing.T, err error) {
	t.Helper()
	if err != nil {
		t.Fatal(err)
	}
}
func fixture(t *testing.T) Runtime {
	t.Helper()
	base := t.TempDir()
	r := Runtime{Context: Context{Repository: filepath.Join(base, "repo"), User: "user", Host: "host", Profile: "hyprland", Programs: []string{"demo"}}, Home: filepath.Join(base, "home")}
	must(t, os.MkdirAll(r.Home, 0700))
	must(t, os.MkdirAll(filepath.Join(r.Repository, "dotfiles/apps"), 0700))
	must(t, writeJSON(filepath.Join(r.Repository, "dotfiles/apps/demo.json"), Manifest{1, "demo", []string{".config/demo", ".demo-file"}}))
	must(t, writeJSON(filepath.Join(r.Repository, "dotfiles/apps/other.json"), Manifest{1, "other", []string{".config/other"}}))
	put(t, filepath.Join(r.Repository, "dotfiles/config/programs/demo/.config/demo/settings"), "base\n")
	put(t, filepath.Join(r.Repository, "dotfiles/config/users/user/programs/demo/.config/demo/settings"), "personal\n")
	put(t, filepath.Join(r.Repository, "dotfiles/config/hosts/host/profiles/hyprland/.config/demo/host"), "hardware\n")
	put(t, filepath.Join(r.Repository, "dotfiles/config/programs/demo/.demo-file"), "single file\n")
	put(t, filepath.Join(r.Repository, "dotfiles/config/profiles/hyprland/.config/other/settings"), "other\n")
	must(t, r.load())
	return r
}

func TestRoundTripFullReplacementAndIsolation(t *testing.T) {
	r := fixture(t)
	app, err := r.app("demo")
	must(t, err)
	put(t, filepath.Join(r.Home, ".config/demo/stale"), "delete on pull")
	put(t, filepath.Join(r.Home, ".config/other/settings"), "do not touch")
	first, err := r.apply(app)
	must(t, err)
	if textAt(t, filepath.Join(r.Home, ".config/demo/settings")) != "personal\n" {
		t.Fatal("precedence lost")
	}
	if present, _ := exists(filepath.Join(r.Home, ".config/demo/stale")); present {
		t.Fatal("pull did not delete stale content")
	}
	if textAt(t, filepath.Join(r.Home, ".config/other/settings")) != "do not touch" {
		t.Fatal("another app changed")
	}
	put(t, filepath.Join(r.Home, ".config/demo/new"), "new local file\n")
	must(t, os.Remove(filepath.Join(r.Home, ".config/demo/host")))
	_, err = r.save(app)
	must(t, err)
	if textAt(t, filepath.Join(r.snapshot(app), "home/.config/demo/new")) != "new local file\n" {
		t.Fatal("push missing new file")
	}
	put(t, filepath.Join(r.snapshot(app), "home/.config/demo/repo-stale"), "stale repo")
	_, err = r.save(app)
	must(t, err)
	if present, _ := exists(filepath.Join(r.snapshot(app), "home/.config/demo/repo-stale")); present {
		t.Fatal("push did not replace full snapshot")
	}
	put(t, filepath.Join(r.Home, ".config/demo/settings"), "different")
	_, err = r.apply(app)
	must(t, err)
	if textAt(t, filepath.Join(r.Home, ".config/demo/settings")) != "personal\n" {
		t.Fatal("snapshot did not round trip")
	}
	if present, _ := exists(filepath.Join(r.Home, ".config/demo/host")); present {
		t.Fatal("deleted file came back from lower layer")
	}
	_, err = r.restore(first)
	must(t, err)
	if textAt(t, filepath.Join(r.Home, ".config/demo/stale")) != "delete on pull" {
		t.Fatal("restore failed")
	}
	if present, _ := exists(filepath.Join(r.Home, ".demo-file")); present {
		t.Fatal("restore did not restore absence")
	}
}

func TestEmptyDirectoryAndDeletedRootRoundTrip(t *testing.T) {
	r := fixture(t)
	app, _ := r.app("demo")
	_, err := r.apply(app)
	must(t, err)
	must(t, os.MkdirAll(filepath.Join(r.Home, ".config/demo/empty"), 0700))
	must(t, os.Remove(filepath.Join(r.Home, ".demo-file")))
	_, err = r.save(app)
	must(t, err)
	must(t, os.RemoveAll(filepath.Join(r.Home, ".config/demo")))
	_, err = r.apply(app)
	must(t, err)
	if info, err := os.Stat(filepath.Join(r.Home, ".config/demo/empty")); err != nil || !info.IsDir() {
		t.Fatal("empty directory lost", err)
	}
	if present, _ := exists(filepath.Join(r.Home, ".demo-file")); present {
		t.Fatal("deleted root restored unexpectedly")
	}
}

func TestDiffFindsAddModifyDeleteAndExecutableChanges(t *testing.T) {
	r := fixture(t)
	app, _ := r.app("demo")
	_, err := r.apply(app)
	must(t, err)
	put(t, filepath.Join(r.Home, ".config/demo/settings"), "changed")
	put(t, filepath.Join(r.Home, ".config/demo/local-only"), "new")
	must(t, os.Remove(filepath.Join(r.Home, ".config/demo/host")))
	must(t, os.Chmod(filepath.Join(r.Home, ".demo-file"), 0755))
	src, paths, err := r.prepared(app)
	must(t, err)
	defer os.RemoveAll(src)
	changes, err := differences(src, r.Home, paths)
	must(t, err)
	want := []Change{{"A", ".config/demo/host"}, {"D", ".config/demo/local-only"}, {"M", ".config/demo/settings"}, {"M", ".demo-file"}}
	if !reflect.DeepEqual(changes, want) {
		t.Fatalf("got %v want %v", changes, want)
	}
}

func TestBootstrapPreservesEditsAndRemovalsAcrossRebuilds(t *testing.T) {
	r := fixture(t)
	put(t, filepath.Join(r.Home, ".config/demo/settings"), "personal live edit")
	unlock, err := r.lock()
	must(t, err)
	defer unlock()
	must(t, r.bootstrap())
	if textAt(t, filepath.Join(r.Home, ".config/demo/settings")) != "personal live edit" {
		t.Fatal("bootstrap imposed repo")
	}
	must(t, os.Remove(filepath.Join(r.Home, ".config/demo/host")))
	put(t, filepath.Join(r.Repository, "dotfiles/config/hosts/host/profiles/hyprland/.config/demo/host"), "new repo content")
	must(t, r.bootstrap())
	if present, _ := exists(filepath.Join(r.Home, ".config/demo/host")); present {
		t.Fatal("rebuild re-seeded user deletion")
	}
}

func TestBootstrapMaterializesStoreLinksAsWritableCopies(t *testing.T) {
	r := fixture(t)
	store := filepath.Join(runtime.GOROOT(), "VERSION")
	resolved, err := filepath.EvalSymlinks(store)
	if err != nil || !strings.HasPrefix(resolved, "/nix/store/") {
		t.Skip("requires Nix Go installation")
	}
	dst := filepath.Join(r.Home, ".config/demo/settings")
	must(t, os.MkdirAll(filepath.Dir(dst), 0700))
	must(t, os.Symlink(store, dst))
	unlock, err := r.lock()
	must(t, err)
	defer unlock()
	must(t, r.bootstrap())
	info, err := os.Lstat(dst)
	must(t, err)
	if info.Mode()&os.ModeSymlink != 0 || info.Mode().Perm()&0200 == 0 {
		t.Fatal("not a writable copy")
	}
	if textAt(t, dst) != "personal\n" {
		t.Fatal("legacy link was not replaced with selected repo config")
	}
}

func TestRejectsTraversalSharedRootsAndOverlappingManifests(t *testing.T) {
	for _, path := range []string{"", ".", "../escape", "/tmp/config", ".config", ".local/bin", "a/../b", ".git/config", ".ssh"} {
		if validPath(path) == nil {
			t.Errorf("accepted unsafe path %q", path)
		}
	}
	r := fixture(t)
	must(t, writeJSON(filepath.Join(r.Repository, "dotfiles/apps/collision.json"), Manifest{1, "collision", []string{".config/demo/child"}}))
	r.Apps = nil
	if err := r.load(); err == nil {
		t.Fatal("overlapping apps accepted")
	}
}

func TestSymlinkParentPreflightLeavesEveryPathUnchanged(t *testing.T) {
	r := fixture(t)
	app, _ := r.app("demo")
	outside := t.TempDir()
	put(t, filepath.Join(outside, "keep"), "untouched")
	must(t, os.Symlink(outside, filepath.Join(r.Home, ".config")))
	put(t, filepath.Join(r.Home, ".demo-file"), "old file")
	if _, err := r.apply(app); err == nil {
		t.Fatal("followed linked parent")
	}
	if textAt(t, filepath.Join(r.Home, ".demo-file")) != "old file" || textAt(t, filepath.Join(outside, "keep")) != "untouched" {
		t.Fatal("preflight mutated data")
	}
}

func TestExternalSourceLinkIsRejectedBeforeReplacingAnything(t *testing.T) {
	r := fixture(t)
	app, _ := r.app("demo")
	outside := filepath.Join(t.TempDir(), "private")
	put(t, outside, "private data")
	source := r.Files[".config/demo/settings"]
	must(t, os.Remove(source))
	must(t, os.Symlink(outside, source))
	put(t, filepath.Join(r.Home, ".demo-file"), "keep")
	if _, err := r.apply(app); err == nil {
		t.Fatal("external link exported")
	}
	if textAt(t, filepath.Join(r.Home, ".demo-file")) != "keep" {
		t.Fatal("changed destination on source failure")
	}
}

func TestRelativeLinksAndModesSurviveFullDirectorySnapshot(t *testing.T) {
	r := fixture(t)
	app, _ := r.app("demo")
	_, err := r.apply(app)
	must(t, err)
	must(t, os.Symlink("settings", filepath.Join(r.Home, ".config/demo/alias")))
	must(t, os.Chmod(filepath.Join(r.Home, ".config/demo/settings"), 0755))
	_, err = r.save(app)
	must(t, err)
	_, err = r.apply(app)
	must(t, err)
	link, err := os.Readlink(filepath.Join(r.Home, ".config/demo/alias"))
	must(t, err)
	if link != "settings" {
		t.Fatal(link)
	}
	info, err := os.Stat(filepath.Join(r.Home, ".config/demo/settings"))
	must(t, err)
	if info.Mode().Perm()&0111 != 0111 {
		t.Fatal("executable bits lost")
	}
}

func TestRepositoryLockAndContextIsolation(t *testing.T) {
	r := fixture(t)
	unlock, err := r.lock()
	must(t, err)
	if release, err := r.lock(); err == nil {
		release()
		t.Fatal("concurrent operation accepted")
	}
	unlock()
	app, _ := r.app("demo")
	_, err = r.apply(app)
	must(t, err)
	_, err = r.save(app)
	must(t, err)
	other := r
	other.Host = "another"
	paths, err := other.activePaths(app)
	must(t, err)
	if len(paths) == 0 {
		t.Fatal("expected base layers still available")
	}
	if other.snapshot(app) == r.snapshot(app) {
		t.Fatal("hosts share writable snapshot")
	}
}

func TestPushBackupCanRestorePreviousSnapshot(t *testing.T) {
	r := fixture(t)
	app, _ := r.app("demo")
	_, err := r.apply(app)
	must(t, err)
	_, err = r.save(app)
	must(t, err)
	put(t, filepath.Join(r.Home, ".config/demo/settings"), "second")
	id, err := r.save(app)
	must(t, err)
	_, err = r.restore(id)
	must(t, err)
	_, err = r.apply(app)
	must(t, err)
	if textAt(t, filepath.Join(r.Home, ".config/demo/settings")) != "personal\n" {
		t.Fatal("push restore lost previous snapshot")
	}
}

func TestGitOmittedEmptyDirectoriesAreRecreated(t *testing.T) {
	r := fixture(t)
	app, _ := r.app("demo")
	_, err := r.apply(app)
	must(t, err)
	must(t, os.MkdirAll(filepath.Join(r.Home, ".config/demo/empty/nested"), 0700))
	_, err = r.save(app)
	must(t, err)
	must(t, os.RemoveAll(filepath.Join(r.snapshot(app), "home/.config/demo/empty")))
	must(t, os.RemoveAll(filepath.Join(r.Home, ".config/demo/empty")))
	_, err = r.apply(app)
	must(t, err)
	if info, err := os.Stat(filepath.Join(r.Home, ".config/demo/empty/nested")); err != nil || !info.IsDir() {
		t.Fatal("Git omitted empty directory lost", err)
	}
}

func TestEntirelyAbsentAppSnapshotRemembersDeletion(t *testing.T) {
	r := fixture(t)
	app, _ := r.app("demo")
	_, err := r.save(app)
	must(t, err)
	put(t, filepath.Join(r.Home, ".config/demo/old"), "must disappear")
	put(t, filepath.Join(r.Home, ".demo-file"), "must disappear")
	_, err = r.apply(app)
	must(t, err)
	for _, path := range []string{".config/demo", ".demo-file"} {
		if present, _ := exists(filepath.Join(r.Home, path)); present {
			t.Fatal("deleted app root came back", path)
		}
	}
}

func TestNewApplicationCanBeSavedWithJustItsManifest(t *testing.T) {
	r := fixture(t)
	app := Manifest{1, "fresh", []string{".config/fresh"}}
	put(t, filepath.Join(r.Home, ".config/fresh/preferences.json"), "fresh user data")
	_, err := r.save(app)
	must(t, err)
	must(t, os.RemoveAll(filepath.Join(r.Home, ".config/fresh")))
	_, err = r.apply(app)
	must(t, err)
	if textAt(t, filepath.Join(r.Home, ".config/fresh/preferences.json")) != "fresh user data" {
		t.Fatal("new app did not round trip")
	}
}

func TestUserContextWorksBeforeSystemActivation(t *testing.T) {
	if _, err := os.Stat("/etc/orgm-dot/context.json"); !os.IsNotExist(err) {
		t.Skip("system context already installed")
	}
	r := fixture(t)
	path := filepath.Join(r.Home, ".local/state/orgm-dot/context.json")
	must(t, os.MkdirAll(filepath.Dir(path), 0700))
	must(t, writeJSON(path, r.Context))
	loaded, err := runtimeFor(options{context: "/etc/orgm-dot/context.json", home: r.Home})
	must(t, err)
	if loaded.Repository != r.Repository || loaded.Profile != r.Profile {
		t.Fatal("user context not loaded")
	}
}
