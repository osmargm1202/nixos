package main

import (
	"path/filepath"
	"testing"
)

func TestLightweightI3LayerIsReusableAndPersonalPreferencesWin(t *testing.T) {
	r := fixture(t)
	r.Profile = "i3"
	r.User = "future-user"
	r.Host = "future-laptop"
	rel := ".config/demo/variant"
	base := filepath.Join(r.Repository, "dotfiles/config")
	put(t, filepath.Join(base, "profiles/i3", rel), "normal")
	put(t, filepath.Join(base, "profiles/i3-lightweight", rel), "light")
	must(t, r.collect())
	if textAt(t, r.Files[rel]) != "normal" {
		t.Fatal("variant selected without opt-in")
	}
	r.Programs = append(r.Programs, "i3-lightweight")
	must(t, r.collect())
	if textAt(t, r.Files[rel]) != "light" {
		t.Fatal("new user/host did not inherit reusable variant")
	}
	put(t, filepath.Join(base, "users/future-user/profiles/i3", rel), "personal")
	must(t, r.collect())
	if textAt(t, r.Files[rel]) != "personal" {
		t.Fatal("variant overrode personal settings")
	}
	r.Profile = "sway"
	must(t, r.collect())
	if _, found := r.Files[rel]; found {
		t.Fatal("i3 variant leaked into another desktop")
	}
}
