package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func registryArgs(t *testing.T, r Runtime) []string {
	t.Helper()
	context := filepath.Join(r.Home, "context.json")
	must(t, writeJSON(context, r.Context))
	return []string{"--context", context, "--home", r.Home}
}

func TestAddCommandAndRejectedRegistrations(t *testing.T) {
	r := fixture(t)
	args := registryArgs(t, r)
	put(t, filepath.Join(r.Home, ".config/fresh/settings"), "local")
	must(t, run(append(args, "add", "fresh", ".config/fresh")))
	loaded, err := runtimeFor(options{context: filepath.Join(r.Home, "context.json"), home: r.Home})
	must(t, err)
	app, err := loaded.app("fresh")
	must(t, err)
	if len(app.Paths) != 1 || app.Paths[0] != ".config/fresh" {
		t.Fatal("wrong manifest", app)
	}
	if present, _ := exists(loaded.snapshot(app)); present {
		t.Fatal("add should register without copying data")
	}
	must(t, run(append(args, "push", "fresh")))
	if textAt(t, filepath.Join(loaded.snapshot(app), "home/.config/fresh/settings")) != "local" {
		t.Fatal("new registration cannot be saved")
	}
	for _, bad := range [][]string{
		{"add", "fresh", ".another"},
		{"add", "bad", "../outside"},
		{"add", "bad", ".config"},
		{"add", "bad", ".config/demo/nested"},
		{"add", "bad", ".safe", ".safe/nested"},
		{"add", "../bad", ".safe"},
		{"add", "bad", ".local/state/orgm-dot/inner"},
	} {
		if err := run(append(args, bad...)); err == nil {
			t.Fatal("unsafe registration accepted", bad)
		}
	}
	must(t, run(append(args, "add", "preview", ".config/preview", "--dry-run")))
	if present, _ := exists(filepath.Join(r.Repository, "dotfiles/apps/preview.json")); present {
		t.Fatal("dry run wrote a manifest")
	}
}

func TestRemoveKeepsHomeOtherContextsAndCanBeRestored(t *testing.T) {
	r := fixture(t)
	app, _ := r.app("demo")
	_, err := r.apply(app)
	must(t, err)
	_, err = r.save(app)
	must(t, err)
	other := r
	other.Host = "other-host"
	put(t, filepath.Join(other.snapshot(app), "home/.config/demo/settings"), "other host")
	id, err := r.remove(app)
	must(t, err)
	if textAt(t, filepath.Join(r.Home, ".config/demo/settings")) != "personal\n" {
		t.Fatal("remove changed live config")
	}
	if textAt(t, filepath.Join(other.snapshot(app), "home/.config/demo/settings")) != "other host" {
		t.Fatal("remove changed another host")
	}
	if present, _ := exists(filepath.Join(r.snapshot(app), "snapshot.json")); present {
		t.Fatal("snapshot was retained")
	}
	args := registryArgs(t, r)
	loaded, err := runtimeFor(options{context: filepath.Join(r.Home, "context.json"), home: r.Home})
	must(t, err)
	available, err := loaded.available()
	must(t, err)
	for _, a := range available {
		if a.Name == "demo" {
			t.Fatal("removed app is available")
		}
	}
	for _, cmd := range []string{"push", "pull", "diff"} {
		if err := run(append(args, cmd, "demo")); err == nil || !strings.Contains(err.Error(), "removed") {
			t.Fatal("removed app accepted an operation", cmd, err)
		}
	}
	must(t, run(append(args, "show", "demo")))
	must(t, run(append(args, "list", "--all")))
	must(t, os.RemoveAll(filepath.Join(r.Home, ".config/demo")))
	must(t, r.bootstrap())
	if present, _ := exists(filepath.Join(r.Home, ".config/demo")); present {
		t.Fatal("bootstrap reintroduced removed app")
	}
	_, err = r.restore(id)
	must(t, err)
	if disabled, err := r.disabled(app); err != nil || disabled {
		t.Fatal("restore did not re-enable application", err)
	}
	_, err = r.apply(app)
	must(t, err)
	if textAt(t, filepath.Join(r.Home, ".config/demo/settings")) != "personal\n" {
		t.Fatal("restore did not recover saved snapshot")
	}
}

func TestRemoveWithoutSavedSnapshotAndDryRun(t *testing.T) {
	r := fixture(t)
	args := registryArgs(t, r)
	app, _ := r.app("demo")
	must(t, run(append(args, "remove", "demo", "--dry-run")))
	if present, _ := exists(r.snapshot(app)); present {
		t.Fatal("dry run changed repository")
	}
	id, err := r.remove(app)
	must(t, err)
	if _, err := r.remove(app); err == nil {
		t.Fatal("duplicate removal must not discard the useful backup")
	}
	_, err = r.restore(id)
	must(t, err)
	if present, _ := exists(r.snapshot(app)); present {
		t.Fatal("restore should recover original snapshot absence")
	}
	_, err = r.apply(app)
	must(t, err)
}
